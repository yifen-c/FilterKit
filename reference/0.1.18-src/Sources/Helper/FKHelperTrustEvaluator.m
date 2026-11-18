#import "FKHelperTrustEvaluator.h"
#import "FKHelperDiscovery.h"
#import "FKHelperMetadata.h"
#import "FKHelperIdentityVerifier.h"
#import "FKHelperSignatureVerifier.h"
#import "FKHelperPermissionVerifier.h"
#import "FKHelperIntegrityVerifier.h"
#import "FKHelperEvidence.h"
#import "FKHelperTrustStore.h"
#import "FKHelperProtocol.h"

@implementation FKHelperTrustEvaluator

+ (FKHelperTrustReport *)evaluateCandidates:(NSArray<NSDictionary *> *)candidates
                                       store:(FKHelperTrustStore *)store {
    FKHelperTrustReport *report = [FKHelperTrustReport new];
    report.checkedAt = [NSDate date];
    // 0.1.18 规划身份口径：Helper 标识与构建标识为模型默认值；清单无可信锚点，保持 unavailable。
    report.helperID = @"com.filterkit.helper";
    report.buildID = @"FKH-0118";
    report.manifestStatus = @"unavailable";
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];
    NSMutableArray<NSString *> *reasonCodes = [NSMutableArray array];
    FKHelperTrustStore *anchorStore = store ?: [FKHelperTrustStore new];

    // 阶段一默认能力：本地只读可评估，写操作与真实操作全部锁定。
    report.permissionReadOnly = YES;
    report.permissionWrite = NO;
    report.realOperationAllowed = NO;
    report.ipcStatus = FKHelperIPCUnavailable;

    // 发现层：只做候选选择与元数据采集，不产生身份可信结论。
    FKHelperMetadata *metadata = [FKHelperDiscovery bestMetadataForCandidates:candidates];
    FKHelperDiscoveryStatus discoveryStatus = [FKHelperDiscovery statusForMetadata:metadata];
    report.discoveryStatus = discoveryStatus;

    if (discoveryStatus == FKHelperDiscoveryNotFound || !metadata) {
        report.state = FKHelperTrustStateNotFound;
        report.identityStatus = FKHelperIdentityUnknown;
        report.integrityStatus = FKHelperIntegrityUnknown;
        [reasons addObject:@"未发现身份可识别的 RootHelper 候选"];
        [reasonCodes addObject:@"helper_endpoint_unavailable"];
        report.reasons = reasons.copy;
        report.reasonCodes = reasonCodes.copy;
        return report;
    }

    NSString *path = metadata.path;
    NSString *packageID = metadata.packageIDs.firstObject ?: @"";
    NSString *version = metadata.version ?: @"";

    report.path = path;
    report.packageID = packageID;
    report.version = version;

    // 0.1.15：结构异常、路径不安全、非普通文件、不可执行或系统工具候选，
    // 在任何摘要/签名/身份文件读取前终止，避免把不可信路径交给后续验证器。
    if (!metadata.candidateSchemaValid || !metadata.pathIsAbsolute || metadata.pathHasTraversal ||
        !metadata.regularFile || !metadata.executable || metadata.systemToolCandidate) {
        report.state = (discoveryStatus == FKHelperDiscoveryInvalid) ? FKHelperTrustStateRejected : FKHelperTrustStateDiscovered;
        report.identityStatus = FKHelperIdentityUnknown;
        report.signatureStatus = FKSignatureStatusUnsupported;
        report.integrityStatus = FKHelperIntegrityUnknown;
        report.identityVerified = NO;
        report.signatureVerified = NO;
        report.permissionVerified = NO;
        report.ipcVerified = NO;
        report.permissionReadOnly = YES;
        report.permissionWrite = NO;
        report.realOperationAllowed = NO;
        if (metadata.validationIssues.count > 0) {
            [reasons addObjectsFromArray:metadata.validationIssues];
            [reasonCodes addObject:metadata.validationIssues.firstObject];
        } else if (metadata.systemToolCandidate) {
            [reasons addObject:@"候选属于系统工具，跳过 Helper 文件验证"];
            [reasonCodes addObject:@"system_tool_candidate"];
        } else if (!metadata.executable) {
            [reasons addObject:@"候选文件不可执行，跳过后续文件验证"];
            [reasonCodes addObject:@"not_executable"];
        } else {
            [reasons addObject:@"候选不是可验证的普通可执行文件"];
            [reasonCodes addObject:@"candidate_not_regular_executable"];
        }
        report.reasons = reasons.copy;
        report.reasonCodes = reasonCodes.copy;
        return report;
    }

    // 采集详细证据：路径类型、可执行权限、归属包与信任链来源。
    FKHelperEvidence *evidence = [FKHelperEvidence new];
    evidence.path = path;
    evidence.packageID = packageID;
    evidence.version = version;
    evidence.checkedAt = report.checkedAt;
    evidence.fileType = metadata.regularFile ? @"regular" : (metadata.exists ? @"directory" : @"unknown");
    evidence.executable = metadata.executable;
    evidence.trustChainSource = [anchorStore anchorSourceForPackageID:packageID];
    evidence.packageSource = [anchorStore hasTrustedAnchorForPackageID:packageID] ? @"confirmed_package" : @"unknown";
    // 本地摘要仅记录文件身份与变化；无可信发布锚点时完整性保持 Unknown，不据此判可信。
    evidence.fileDigest = [FKHelperIntegrityVerifier localSHA256ForPath:path] ?: @"";
    report.evidence = evidence;

    if (discoveryStatus == FKHelperDiscoveryInvalid) {
        [reasons addObject:@"候选文件类型不符合预期，不能作为 Helper 身份证据"];
        [reasonCodes addObject:@"candidate_invalid"];
    } else if (metadata.systemToolCandidate) {
        [reasons addObject:@"候选为普通系统工具，不属于 FilterKit Helper"];
        [reasonCodes addObject:@"system_tool_candidate"];
    } else if (metadata.missingFields.count > 0) {
        [reasons addObject:[NSString stringWithFormat:@"必要元数据缺失：%@", [metadata.missingFields componentsJoinedByString:@", "]]];
        [reasonCodes addObject:@"metadata_incomplete"];
    }

    // 身份细化评估。
    report.identityStatus = [FKHelperIdentityVerifier verifyIdentityStatusWithPath:path
                                                                          packageID:packageID
                                                                            version:version
                                                                         identifier:metadata.identifier
                                                                            reasons:reasons];
    report.identityVerified = (report.identityStatus == FKHelperIdentityVerified);
    switch (report.identityStatus) {
        case FKHelperIdentityUnknown: [reasonCodes addObject:@"trusted_source_missing"]; break;
        case FKHelperIdentityMismatch: [reasonCodes addObject:@"identity_mismatch"]; break;
        case FKHelperIdentityIncomplete: [reasonCodes addObject:@"identity_incomplete"]; break;
        case FKHelperIdentityVerified: break;
    }

    // 签名评估：当前未接入可用签名校验 API，按 Unsupported 保守处理。
    report.signatureStatus = [FKHelperSignatureVerifier verifySignatureWithPath:path reasons:reasons];
    report.signatureVerified = (report.signatureStatus == FKSignatureStatusVerified || report.signatureStatus == FKSignatureStatusValid);
    [reasonCodes addObject:@"signature_unverified"];

    // 完整性评估：无可信锚点保持 Unknown。
    report.integrityStatus = [FKHelperIntegrityVerifier verifyIntegrityWithPath:path trustedSHA256:nil reasons:reasons];
    switch (report.integrityStatus) {
        case FKHelperIntegrityUnknown: [reasonCodes addObject:@"integrity_anchor_missing"]; break;
        case FKHelperIntegrityMismatch: [reasonCodes addObject:@"integrity_mismatch"]; break;
        case FKHelperIntegrityUnavailable: [reasonCodes addObject:@"integrity_unavailable"]; break;
        case FKHelperIntegrityVerified: break;
    }

    report.permissionVerified = [FKHelperPermissionVerifier verifyPermissionForOperationName:FKHelperOperationNameGetStatus reasons:reasons];
    report.ipcVerified = NO;
    [reasons addObject:@"尚未建立受控 IPC 通道，通信协议未通过验收"];
    [reasonCodes addObject:@"helper_endpoint_unavailable"];

    // 定级：关键证据缺失即停在对应级别；身份与包均无法追溯时拒绝。
    if (!report.identityVerified && packageID.length == 0) {
        report.state = FKHelperTrustStateRejected;
    } else if (!report.identityVerified) {
        report.state = FKHelperTrustStateDiscovered;
    } else if (!report.signatureVerified) {
        report.state = FKHelperTrustStateIdentityVerified;
    } else if (!report.permissionVerified) {
        report.state = FKHelperTrustStateSignatureVerified;
    } else if (!report.ipcVerified) {
        report.state = FKHelperTrustStatePermissionVerified;
    } else {
        report.state = FKHelperTrustStateOperationReady;
    }

    report.reasons = reasons.copy;
    report.reasonCodes = reasonCodes.copy;
    return report;
}

@end
