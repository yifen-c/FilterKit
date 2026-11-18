#import "FKHelperTrustVerifier.h"
#import "FKHelperIdentityVerifier.h"
#import "FKHelperSignatureVerifier.h"
#import "FKHelperPermissionVerifier.h"
#import "FKHelperProtocol.h"

@implementation FKHelperTrustVerifier

+ (FKHelperTrustReport *)evaluateCandidates:(NSArray<NSDictionary *> *)candidates {
    FKHelperTrustReport *report = [FKHelperTrustReport new];
    report.checkedAt = [NSDate date];
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];

    // 阶段一默认口径：本地只读可评估，写操作与真实操作锁定，IPC 未连接。
    report.permissionReadOnly = YES;
    report.permissionWrite = NO;
    report.realOperationAllowed = NO;
    report.ipcStatus = FKHelperIPCUnavailable;
    report.identityStatus = FKHelperIdentityUnknown;
    report.integrityStatus = FKHelperIntegrityUnknown;

    // 仅保留真实存在的候选；文件名或 Label 同名不作为身份证据。
    NSDictionary *candidate = nil;
    for (NSDictionary *item in candidates) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        if ([item[@"exists"] boolValue]) { candidate = item; break; }
    }

    if (!candidate) {
        report.state = FKHelperTrustStateNotFound;
        [reasons addObject:@"未发现身份可识别的 RootHelper 候选"];
        report.reasons = reasons.copy;
        return report;
    }

    NSString *path = candidate[@"path"] ?: candidate[@"logical_path"] ?: @"";
    NSArray *packageIDs = [candidate[@"package_ids"] isKindOfClass:NSArray.class] ? candidate[@"package_ids"] : @[];
    NSString *packageID = packageIDs.firstObject ?: @"";
    NSString *version = candidate[@"version"] ?: @"";

    report.path = path;
    report.packageID = packageID;
    report.version = version;

    // 逐级评估：身份 → 签名 → 权限；IPC 通道本轮未建立。
    report.identityVerified = [FKHelperIdentityVerifier verifyIdentityWithPath:path packageID:packageID version:version reasons:reasons];
    report.identityStatus = report.identityVerified ? FKHelperIdentityVerified : FKHelperIdentityUnknown;
    report.signatureStatus = [FKHelperSignatureVerifier verifySignatureWithPath:path reasons:reasons];
    report.signatureVerified = (report.signatureStatus == FKSignatureStatusVerified);
    report.permissionVerified = [FKHelperPermissionVerifier verifyPermissionForOperationName:FKHelperOperationNameGetStatus reasons:reasons];
    report.ipcVerified = NO;
    [reasons addObject:@"尚未建立受控 IPC 通道，通信协议未通过验收"];

    // 按已通过的最高级别定级；关键证据缺失则停在已发现或拒绝。
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
    return report;
}

@end
