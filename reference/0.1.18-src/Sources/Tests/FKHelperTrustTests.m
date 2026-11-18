#import "FKHelperTrustTests.h"
#import "FKHelperDiscovery.h"
#import "FKHelperMetadata.h"
#import "FKHelperIdentityVerifier.h"
#import "FKHelperIntegrityVerifier.h"
#import "FKHelperSignatureVerifier.h"
#import "FKHelperIPCHandshake.h"
#import "FKHelperIPCCapabilities.h"
#import "FKHelperCapabilityManager.h"
#import "FKOperationPermissionEvaluator.h"
#import "FKHelperTrustEvaluator.h"
#import "FKHelperTrust.h"
#import "FKHelperProtocol.h"
#import "FKOperationGate.h"
#import "FKOperationEligibility.h"
#import "FKOperationModels.h"
#import "FKManageModels.h"

@implementation FKHelperTrustTests

+ (NSUInteger)checkCount { return 53; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // DISC701：无候选文件返回 NotFound。
    FKHelperMetadata *none = [FKHelperDiscovery bestMetadataForCandidates:@[]];
    if ([FKHelperDiscovery statusForMetadata:none] != FKHelperDiscoveryNotFound) {
        [failures addObject:@"DISC701 无候选应返回 NotFound"];
    }

    // DISC702：形态完整的存在候选返回 Found。
    NSDictionary *complete = @{
        @"path": @"/var/jb/usr/libexec/FilterKitHelper",
        @"exists": @YES, @"regular_file": @YES, @"executable": @YES, @"size": @(1024),
        @"package_ids": @[@"com.filterkit.helper"],
        @"version": @"1.0.0", @"helper_id": @"com.filterkit.helper", @"protocol_version": @(1)
    };
    FKHelperMetadata *found = [FKHelperDiscovery bestMetadataForCandidates:@[complete]];
    if ([FKHelperDiscovery statusForMetadata:found] != FKHelperDiscoveryFound) {
        [failures addObject:@"DISC702 形态完整候选应返回 Found"];
    }

    // DISC703：必要元数据缺失返回 Incomplete。
    NSDictionary *missingMeta = @{
        @"path": @"/var/jb/usr/libexec/SomeHelper",
        @"exists": @YES, @"regular_file": @YES, @"executable": @YES, @"size": @(512)
    };
    FKHelperMetadata *incomplete = [FKHelperDiscovery bestMetadataForCandidates:@[missingMeta]];
    if ([FKHelperDiscovery statusForMetadata:incomplete] != FKHelperDiscoveryIncomplete) {
        [failures addObject:@"DISC703 元数据缺失应返回 Incomplete"];
    }

    // DISC704：文件类型不符合预期返回 Invalid。
    NSDictionary *directory = @{
        @"path": @"/var/jb/usr/libexec/HelperDir",
        @"exists": @YES, @"regular_file": @NO, @"executable": @NO, @"size": @(0),
        @"package_ids": @[@"com.filterkit.helper"], @"version": @"1.0.0", @"helper_id": @"com.filterkit.helper"
    };
    FKHelperMetadata *invalid = [FKHelperDiscovery bestMetadataForCandidates:@[directory]];
    if ([FKHelperDiscovery statusForMetadata:invalid] != FKHelperDiscoveryInvalid) {
        [failures addObject:@"DISC704 非常规文件应返回 Invalid"];
    }

    // DISC705：普通系统工具不能被识别为 FilterKit Helper。
    NSDictionary *systemTool = @{
        @"path": @"/usr/bin/path_helper",
        @"exists": @YES, @"regular_file": @YES, @"executable": @YES, @"size": @(256)
    };
    FKHelperMetadata *tool = [FKHelperDiscovery bestMetadataForCandidates:@[systemTool]];
    if (!tool.systemToolCandidate || [FKHelperDiscovery statusForMetadata:tool] == FKHelperDiscoveryFound) {
        [failures addObject:@"DISC705 系统工具候选不应被识别为 FilterKit Helper"];
    }

    // DISC706：Discovery 不得自行产生可信结论 Verified。
    NSArray<FKHelperMetadata *> *all = [FKHelperDiscovery metadataForCandidates:@[complete, missingMeta, directory, systemTool]];
    for (FKHelperMetadata *metadata in all) {
        if ([FKHelperDiscovery statusForMetadata:metadata] == FKHelperDiscoveryVerified) {
            [failures addObject:@"DISC706 发现层不得自行返回 Verified"];
            break;
        }
    }

    // 本地临时文件，仅用于身份/完整性本地判定，不触碰越狱文件系统。
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"fk-helper-trust-test.bin"];
    [@"filterkit-trust-test" writeToFile:tmpPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    // ID701：标识与预期不符判 Mismatch。
    NSMutableArray<NSString *> *identityReasons = [NSMutableArray array];
    FKHelperIdentityStatus mismatch = [FKHelperIdentityVerifier verifyIdentityStatusWithPath:tmpPath
                                                                                       packageID:@"com.filterkit.helper"
                                                                                         version:@"1.0.0"
                                                                                      identifier:@"com.other.helper"
                                                                                         reasons:identityReasons];
    if (mismatch != FKHelperIdentityMismatch) [failures addObject:@"ID701 标识不符应判 Mismatch"];

    // ID702：版本信息缺失判 Incomplete。
    NSMutableArray<NSString *> *incompleteReasons = [NSMutableArray array];
    FKHelperIdentityStatus incompleteIdentity = [FKHelperIdentityVerifier verifyIdentityStatusWithPath:tmpPath
                                                                                             packageID:@"com.filterkit.helper"
                                                                                               version:@""
                                                                                            identifier:@"com.filterkit.helper"
                                                                                               reasons:incompleteReasons];
    if (incompleteIdentity != FKHelperIdentityIncomplete) [failures addObject:@"ID702 版本缺失应判 Incomplete"];

    // ID703：字段齐全但无可信发布来源，保持 Unknown，不自动通过。
    NSMutableArray<NSString *> *unknownReasons = [NSMutableArray array];
    FKHelperIdentityStatus unknownIdentity = [FKHelperIdentityVerifier verifyIdentityStatusWithPath:tmpPath
                                                                                           packageID:@"com.filterkit.helper"
                                                                                             version:@"1.0.0"
                                                                                          identifier:@"com.filterkit.helper"
                                                                                             reasons:unknownReasons];
    if (unknownIdentity != FKHelperIdentityUnknown) [failures addObject:@"ID703 来源未知应保持 Unknown"];

    // ID704：路径不存在判 Unknown，不臆断身份。
    NSMutableArray<NSString *> *missingReasons = [NSMutableArray array];
    FKHelperIdentityStatus missingIdentity = [FKHelperIdentityVerifier verifyIdentityStatusWithPath:@"/nonexistent/helper"
                                                                                          packageID:@""
                                                                                            version:@""
                                                                                         identifier:nil
                                                                                            reasons:missingReasons];
    if (missingIdentity != FKHelperIdentityUnknown) [failures addObject:@"ID704 文件不可达应判 Unknown"];

    // INT701：文件不存在/不可读返回 Unavailable。
    NSMutableArray<NSString *> *unavailableReasons = [NSMutableArray array];
    if ([FKHelperIntegrityVerifier verifyIntegrityWithPath:@"/nonexistent/helper" trustedSHA256:nil reasons:unavailableReasons] != FKHelperIntegrityUnavailable) {
        [failures addObject:@"INT701 摘要不可用应返回 Unavailable"];
    }

    // INT702：无可信摘要锚点时不允许判通过，保持 Unknown。
    NSMutableArray<NSString *> *noAnchorReasons = [NSMutableArray array];
    if ([FKHelperIntegrityVerifier verifyIntegrityWithPath:tmpPath trustedSHA256:nil reasons:noAnchorReasons] != FKHelperIntegrityUnknown) {
        [failures addObject:@"INT702 缺少可信锚点应保持 Unknown"];
    }

    // INT703：本地摘要与可信记录匹配判 Verified。
    NSString *localDigest = [FKHelperIntegrityVerifier localSHA256ForPath:tmpPath];
    NSMutableArray<NSString *> *matchReasons = [NSMutableArray array];
    if (localDigest.length == 0 || [FKHelperIntegrityVerifier verifyIntegrityWithPath:tmpPath trustedSHA256:localDigest reasons:matchReasons] != FKHelperIntegrityVerified) {
        [failures addObject:@"INT703 摘要匹配应判 Verified"];
    }

    // INT704：摘要与可信记录不一致判 Mismatch。
    NSMutableArray<NSString *> *mismatchReasons = [NSMutableArray array];
    if ([FKHelperIntegrityVerifier verifyIntegrityWithPath:tmpPath trustedSHA256:@"deadbeefdeadbeef" reasons:mismatchReasons] != FKHelperIntegrityMismatch) {
        [failures addObject:@"INT704 摘要不匹配应判 Mismatch"];
    }

    // IPC701：握手请求序列化携带客户端与协议版本。
    FKHelperIPCHandshakeRequest *handshake = [FKHelperIPCHandshakeRequest requestWithClientVersion:@"0.1.18" protocolVersion:FKHelperProtocolVersion];
    NSDictionary *handshakeJSON = handshake.JSONDictionary;
    if (![handshakeJSON[@"client"] isEqualToString:@"FilterKit"] || [handshakeJSON[@"protocol_version"] integerValue] != FKHelperProtocolVersion) {
        [failures addObject:@"IPC701 握手请求应携带客户端与协议版本"];
    }

    // IPC702：字段齐全的握手响应通过本地校验。
    FKHelperIPCHandshakeResponse *okResponse = [FKHelperIPCHandshakeResponse responseFromDictionary:@{
        @"helper_id": @"com.filterkit.helper", @"helper_version": @"1.0.0",
        @"protocol_version": @(FKHelperProtocolVersion), @"status": @"ready",
        @"capabilities": @[@"plugin.list"]
    }];
    NSError *hsError = nil;
    if (![okResponse validateWithError:&hsError]) [failures addObject:@"IPC702 合法握手响应应通过校验"];

    // IPC703：协议版本不兼容的响应被拒绝。
    FKHelperIPCHandshakeResponse *badVersion = [FKHelperIPCHandshakeResponse responseFromDictionary:@{
        @"helper_id": @"com.filterkit.helper", @"protocol_version": @(999), @"status": @"ready"
    }];
    if ([badVersion validateWithError:&hsError]) [failures addObject:@"IPC703 版本不兼容响应应被拒绝"];

    // IPC704：缺少对端身份标识的响应被拒绝。
    FKHelperIPCHandshakeResponse *noPeer = [FKHelperIPCHandshakeResponse responseFromDictionary:@{
        @"protocol_version": @(FKHelperProtocolVersion), @"status": @"ready"
    }];
    if ([noPeer validateWithError:&hsError]) [failures addObject:@"IPC704 缺对端标识响应应被拒绝"];

    // IPC705：无可信端点时连接状态为 Unavailable。
    if (![[FKHelperIPCHandshake statusCodeForStatus:FKHelperIPCUnavailable] isEqualToString:@"UNAVAILABLE"]) {
        [failures addObject:@"IPC705 不可用状态应映射 UNAVAILABLE"];
    }

    // IPC706：阶段一默认能力仅含本地只读，写能力为空。
    FKHelperIPCCapabilities *defaultCaps = [FKHelperCapabilityManager defaultCapabilities];
    if (![defaultCaps.readOnlyPermissions containsObject:@"local.plugin.inspect"] || defaultCaps.writePermissions.count != 0) {
        [failures addObject:@"IPC706 默认能力应仅开放本地只读且写能力为空"];
    }

    // PER701：本地只读检查允许。
    NSMutableArray<NSString *> *permReasons = [NSMutableArray array];
    if (![FKOperationPermissionEvaluator allowPermission:@"local.plugin.inspect" identityVerified:NO ipcConnected:NO protocolCompatible:NO reasons:permReasons]) {
        [failures addObject:@"PER701 本地只读检查应允许"];
    }

    // PER702：写操作在所有模拟条件满足时仍必须拒绝。
    NSMutableArray<NSString *> *writeReasons = [NSMutableArray array];
    if ([FKOperationPermissionEvaluator allowPermission:@"plugin.enable" identityVerified:YES ipcConnected:YES protocolCompatible:YES reasons:writeReasons]) {
        [failures addObject:@"PER702 阶段一写操作必须拒绝"];
    }

    // PER703：IPC 只读在身份未验证 / 未连接 / 不兼容时拒绝。
    NSMutableArray<NSString *> *ipcReasons = [NSMutableArray array];
    if ([FKOperationPermissionEvaluator allowPermission:@"ipc.plugin.list" identityVerified:NO ipcConnected:NO protocolCompatible:NO reasons:ipcReasons]) {
        [failures addObject:@"PER703 IPC 只读证据不足时应拒绝"];
    }

    // PER704：IPC 只读在身份、连接、协议均满足时才允许。
    NSMutableArray<NSString *> *ipcOkReasons = [NSMutableArray array];
    if (![FKOperationPermissionEvaluator allowPermission:@"ipc.plugin.list" identityVerified:YES ipcConnected:YES protocolCompatible:YES reasons:ipcOkReasons]) {
        [failures addObject:@"PER704 IPC 只读条件满足时应允许"];
    }

    // PER705：未识别权限键拒绝。
    NSMutableArray<NSString *> *unknownReasonsPerm = [NSMutableArray array];
    if ([FKOperationPermissionEvaluator allowPermission:@"system.run" identityVerified:YES ipcConnected:YES protocolCompatible:YES reasons:unknownReasonsPerm]) {
        [failures addObject:@"PER705 未识别权限键应拒绝"];
    }

    // ID705：兼容旧 BOOL 接口在无可信来源场景下不应判通过。
    NSMutableArray<NSString *> *legacyReasons = [NSMutableArray array];
    if ([FKHelperIdentityVerifier verifyIdentityWithPath:tmpPath packageID:@"com.filterkit.helper" version:@"1.0.0" reasons:legacyReasons]) {
        [failures addObject:@"ID705 无可信来源旧接口不应判通过"];
    }

    // ID706：身份不符时应在原因列表中留下记录。
    NSMutableArray<NSString *> *mismatchReasonsID = [NSMutableArray array];
    [FKHelperIdentityVerifier verifyIdentityStatusWithPath:tmpPath packageID:@"com.filterkit.helper" version:@"1.0.0" identifier:@"com.other.helper" reasons:mismatchReasonsID];
    if (mismatchReasonsID.count == 0) [failures addObject:@"ID706 身份不符应记录拒绝原因"];

    // ID707：空路径与空标识不崩溃，且保持 Unknown。
    NSMutableArray<NSString *> *emptyIdentityReasons = [NSMutableArray array];
    if ([FKHelperIdentityVerifier verifyIdentityStatusWithPath:@"" packageID:@"" version:@"" identifier:nil reasons:emptyIdentityReasons] != FKHelperIdentityUnknown) {
        [failures addObject:@"ID707 空身份信息应保持 Unknown"];
    }

    // INT705：本地摘要为非空十六进制字符串。
    NSString *digest = [FKHelperIntegrityVerifier localSHA256ForPath:tmpPath];
    if (digest.length != 64) [failures addObject:@"INT705 本地 SHA-256 应为 64 位十六进制"];

    // INT706：摘要不可用场景应记录原因。
    NSMutableArray<NSString *> *unavailableReasonsINT = [NSMutableArray array];
    [FKHelperIntegrityVerifier verifyIntegrityWithPath:@"/nonexistent/helper" trustedSHA256:nil reasons:unavailableReasonsINT];
    if (unavailableReasonsINT.count == 0) [failures addObject:@"INT706 摘要不可用应记录原因"];

    // INT707：摘要不匹配场景应记录原因。
    NSMutableArray<NSString *> *mismatchReasonsINT = [NSMutableArray array];
    [FKHelperIntegrityVerifier verifyIntegrityWithPath:tmpPath trustedSHA256:@"deadbeefdeadbeef" reasons:mismatchReasonsINT];
    if (mismatchReasonsINT.count == 0) [failures addObject:@"INT707 摘要不匹配应记录原因"];

    // 签名 API 不支持时不得臆断 Valid/Verified，保持保守状态。
    NSMutableArray<NSString *> *signatureReasons = [NSMutableArray array];
    FKSignatureStatus sigStatus = [FKHelperSignatureVerifier verifySignatureWithPath:tmpPath reasons:signatureReasons];
    if (sigStatus == FKSignatureStatusValid || sigStatus == FKSignatureStatusVerified) {
        [failures addObject:@"签名证据不足时不得判为有效签名"];
    }

    // IPC707：非字典输入构造握手响应返回 nil。
    if ([FKHelperIPCHandshakeResponse responseFromDictionary:(id)[NSArray array]] != nil) {
        [failures addObject:@"IPC707 非字典响应应返回 nil"];
    }

    // IPC708：能力清单权限归属判定。
    FKHelperIPCCapabilities *caps = [FKHelperIPCCapabilities capabilitiesWithReadOnly:@[@"local.plugin.inspect"] write:@[@"plugin.enable"]];
    if (![caps containsPermission:@"plugin.enable"] || ![caps isWritePermission:@"plugin.enable"]) {
        [failures addObject:@"IPC708 写权限应被识别为写能力"];
    }
    if ([caps isWritePermission:@"local.plugin.inspect"]) [failures addObject:@"IPC708 本地只读不应被判为写权限"];

    // PER706：删除/禁用属写操作，本地只读集合不含写键。
    if (![[FKHelperCapabilityManager writePermissions] containsObject:@"plugin.delete"]) {
        [failures addObject:@"PER706 plugin.delete 应归入写权限"];
    }

    // PER707：本地只读与写权限集合互不相交。
    if ([[FKHelperCapabilityManager localReadOnlyPermissions] intersectsSet:[FKHelperCapabilityManager writePermissions]]) {
        [failures addObject:@"PER707 只读与写权限集合不应重叠"];
    }

    // PER708：IPC 只读在协议不兼容时即使身份已验证、已连接也应拒绝。
    NSMutableArray<NSString *> *compatReasons = [NSMutableArray array];
    if ([FKOperationPermissionEvaluator allowPermission:@"ipc.config.read" identityVerified:YES ipcConnected:YES protocolCompatible:NO reasons:compatReasons]) {
        [failures addObject:@"PER708 协议不兼容时 IPC 只读应拒绝"];
    }

    // ---- 报告分层输出（REP）----
    FKHelperTrustReport *emptyReport = [FKHelperTrustEvaluator evaluateCandidates:@[] store:nil];
    NSDictionary *repJSON = emptyReport.JSONDictionary;

    // REP701：空候选报告定级为未发现。
    if (![repJSON[@"state"] isEqualToString:@"NOT_FOUND"]) [failures addObject:@"REP701 空候选状态应为 NOT_FOUND"];

    // REP702：JSON 携带发现/身份/签名/完整性/IPC/权限分层段。
    for (NSString *key in @[@"discovery", @"identity", @"signature", @"integrity", @"ipc", @"permission"]) {
        if (![repJSON[key] isKindOfClass:NSDictionary.class]) [failures addObject:@"REP702 报告应包含完整分层段"];
    }

    // REP703：阶段一写能力与真实操作锁定。
    NSDictionary *permissionJSON = repJSON[@"permission"];
    if ([permissionJSON[@"write"] boolValue] || [repJSON[@"real_operation_allowed"] boolValue]) {
        [failures addObject:@"REP703 阶段一写能力与真实操作必须为 NO"];
    }

    // REP704：本地只读能力评估可用。
    if (![permissionJSON[@"read_only"] boolValue]) [failures addObject:@"REP704 本地只读能力应为可用"];

    // REP705：未验证身份不得记录为已验证。
    NSDictionary *identityJSON = repJSON[@"identity"];
    if ([identityJSON[@"verified"] boolValue]) [failures addObject:@"REP705 空候选身份不应记为已验证"];

    // REP706：存在机器可读原因码。
    if (![repJSON[@"reason_codes"] isKindOfClass:NSArray.class] || [repJSON[@"reason_codes"] count] == 0) {
        [failures addObject:@"REP706 未通过场景应输出原因码"];
    }

    // REP707：当前签名证据不得判为已验证。
    if ([repJSON[@"signature"][@"status"] isEqualToString:@"verified"]) [failures addObject:@"REP707 阶段一签名不应判为 verified"];

    // REP708：证据字段为字典且检查时间可序列化。
    if (![repJSON[@"evidence"] isKindOfClass:NSDictionary.class] || [repJSON[@"checked_at"] length] == 0) {
        [failures addObject:@"REP708 证据与时间戳应可序列化"];
    }

    // ---- 操作门禁写操作回归（GATE701–708）----
    FKPluginModel *plugin = [FKPluginModel modelWithDictionary:@{@"PluginID": @"com.test.example:example", @"Name": @"Example"}];

    FKHelperTrustReport *(^makeReport)(BOOL, BOOL, BOOL) = ^(BOOL identityOK, BOOL signatureOK, BOOL ipcOK) {
        FKHelperTrustReport *r = [FKHelperTrustReport new];
        r.identityVerified = identityOK;
        r.signatureVerified = signatureOK;
        r.ipcVerified = ipcOK;
        return r;
    };

    // GATE701：Helper 不存在（无报告）且证据缺失，拒绝真实操作。
    FKOperationEligibility *gateNone = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                           appBundleID:@"com.test.app"
                                                                            operation:FKOperationTypeEnable
                                                                        environmentOK:NO
                                                                     injectorCompatible:NO
                                                                             injector:nil
                                                                         helperReport:nil
                                                                      backupAvailable:NO
                                                                         backupValid:NO
                                                                           scopeClear:NO
                                                                        auditWritable:NO
                                                                      userAuthorized:NO];
    if (![gateNone.status isEqualToString:@"blocked"] || gateNone.eligible) {
        [failures addObject:@"GATE701 Helper 不存在时应拒绝"];
    }

    // GATE702：身份 Unknown，拒绝。
    FKHelperTrustReport *identityUnknown = makeReport(NO, YES, YES);
    identityUnknown.identityStatus = FKHelperIdentityUnknown;
    FKOperationEligibility *gateIdentity = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                             appBundleID:@"com.test.app"
                                                                              operation:FKOperationTypeEnable
                                                                          environmentOK:YES
                                                                       injectorCompatible:YES
                                                                               injector:@"libhooker"
                                                                           helperReport:identityUnknown
                                                                        backupAvailable:YES
                                                                           backupValid:YES
                                                                             scopeClear:YES
                                                                          auditWritable:YES
                                                                        userAuthorized:YES];
    if (![gateIdentity.status isEqualToString:@"blocked"]) [failures addObject:@"GATE702 身份 Unknown 时应拒绝"];

    // GATE703：签名 Invalid，拒绝。
    FKHelperTrustReport *signatureInvalid = makeReport(YES, NO, YES);
    signatureInvalid.signatureStatus = FKSignatureStatusInvalid;
    FKOperationEligibility *gateSignature = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                              appBundleID:@"com.test.app"
                                                                               operation:FKOperationTypeEnable
                                                                           environmentOK:YES
                                                                        injectorCompatible:YES
                                                                                injector:@"libhooker"
                                                                            helperReport:signatureInvalid
                                                                         backupAvailable:YES
                                                                            backupValid:YES
                                                                              scopeClear:YES
                                                                           auditWritable:YES
                                                                         userAuthorized:YES];
    if (![gateSignature.status isEqualToString:@"blocked"]) [failures addObject:@"GATE703 签名 Invalid 时应拒绝"];

    // GATE704：完整性 Unknown，证据不足共同阻断，拒绝。
    FKHelperTrustReport *integrityUnknown = makeReport(NO, NO, NO);
    integrityUnknown.integrityStatus = FKHelperIntegrityUnknown;
    FKOperationEligibility *gateIntegrity = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                               appBundleID:@"com.test.app"
                                                                                operation:FKOperationTypeEnable
                                                                            environmentOK:YES
                                                                         injectorCompatible:YES
                                                                                 injector:@"libhooker"
                                                                             helperReport:integrityUnknown
                                                                          backupAvailable:YES
                                                                             backupValid:YES
                                                                               scopeClear:YES
                                                                            auditWritable:YES
                                                                          userAuthorized:YES];
    if (![gateIntegrity.status isEqualToString:@"blocked"]) [failures addObject:@"GATE704 完整性 Unknown 时应拒绝"];

    // GATE705：IPC Unavailable，拒绝。
    FKHelperTrustReport *ipcUnavailable = makeReport(YES, YES, NO);
    ipcUnavailable.ipcStatus = FKHelperIPCUnavailable;
    FKOperationEligibility *gateIPC = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                           appBundleID:@"com.test.app"
                                                                            operation:FKOperationTypeEnable
                                                                        environmentOK:YES
                                                                     injectorCompatible:YES
                                                                             injector:@"libhooker"
                                                                         helperReport:ipcUnavailable
                                                                      backupAvailable:YES
                                                                         backupValid:YES
                                                                           scopeClear:YES
                                                                        auditWritable:YES
                                                                      userAuthorized:YES];
    if (![gateIPC.status isEqualToString:@"blocked"]) [failures addObject:@"GATE705 IPC Unavailable 时应拒绝"];

    // GATE706：未取得用户授权，拒绝。
    FKOperationEligibility *gateAuth = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                          appBundleID:@"com.test.app"
                                                                           operation:FKOperationTypeEnable
                                                                       environmentOK:YES
                                                                    injectorCompatible:YES
                                                                            injector:@"libhooker"
                                                                        helperReport:nil
                                                                     backupAvailable:YES
                                                                        backupValid:YES
                                                                          scopeClear:YES
                                                                       auditWritable:YES
                                                                     userAuthorized:NO];
    if (![gateAuth.status isEqualToString:@"blocked"]) [failures addObject:@"GATE706 未授权时应拒绝"];

    // GATE707：备份校验无效，拒绝。
    FKOperationEligibility *gateBackup = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                             appBundleID:@"com.test.app"
                                                                              operation:FKOperationTypeEnable
                                                                          environmentOK:YES
                                                                       injectorCompatible:YES
                                                                               injector:@"libhooker"
                                                                           helperReport:nil
                                                                        backupAvailable:YES
                                                                           backupValid:NO
                                                                             scopeClear:YES
                                                                          auditWritable:YES
                                                                        userAuthorized:YES];
    if (![gateBackup.status isEqualToString:@"blocked"]) [failures addObject:@"GATE707 备份无效时应拒绝"];

    // GATE802：发布清单未验证（unavailable），即使身份/签名/IPC 齐备也应阻断真实操作。
    FKHelperTrustReport *manifestMissing = makeReport(YES, YES, YES);
    manifestMissing.manifestStatus = @"unavailable";
    FKOperationEligibility *gateManifest = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                             appBundleID:@"com.test.app"
                                                                              operation:FKOperationTypeEnable
                                                                          environmentOK:YES
                                                                       injectorCompatible:YES
                                                                               injector:@"libhooker"
                                                                           helperReport:manifestMissing
                                                                        backupAvailable:YES
                                                                           backupValid:YES
                                                                             scopeClear:YES
                                                                          auditWritable:YES
                                                                        userAuthorized:YES];
    if (![gateManifest.status isEqualToString:@"blocked"]) [failures addObject:@"GATE802 清单未验证时应拒绝"];

    // GATE708：所有模拟条件通过，仍不能绕过真实验证与授权要求；真实报告写能力保持锁定。
    FKHelperTrustReport *simulatedReport = makeReport(YES, YES, YES);
    FKOperationEligibility *simulated = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                          appBundleID:@"com.test.app"
                                                                           operation:FKOperationTypeEnable
                                                                       environmentOK:YES
                                                                    injectorCompatible:YES
                                                                            injector:@"libhooker"
                                                                        helperReport:simulatedReport
                                                                     backupAvailable:YES
                                                                        backupValid:YES
                                                                          scopeClear:YES
                                                                       auditWritable:YES
                                                                     userAuthorized:YES];
    if (![simulated.mode isEqualToString:@"preview_only"] || simulated.decision == FKOperationDecisionAllowed || [simulated.status isEqualToString:@"ready"]) {
        [failures addObject:@"GATE708 阶段一模拟齐备仍不得放行真实操作"];
    }
    if (emptyReport.permissionWrite || emptyReport.realOperationAllowed) {
        [failures addObject:@"GATE708 真实报告不得开放写能力或真实操作"];
    }

    return failures.copy;
}

@end
