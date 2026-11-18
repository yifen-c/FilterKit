#import "FKHelperGateTests.h"
#import "FKOperationGate.h"
#import "FKOperationEligibility.h"
#import "FKOperationModels.h"
#import "FKManageModels.h"
#import "FKHelperTrust.h"
#import "FKHelperCapabilities.h"
#import "FKCapabilityEvaluator.h"
#import "FKMockHelperClient.h"
#import "FKHelperReadOnlyClient.h"
#import "FKHelperTestTransport.h"
#import "FKHelperTransportState.h"

@implementation FKHelperGateTests

+ (NSUInteger)checkCount { return 10; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    FKPluginModel *plugin = [FKPluginModel modelWithDictionary:@{@"PluginID": @"com.test.example:example", @"Name": @"Example"}];

    FKHelperTrustReport *(^makeReport)(BOOL, BOOL, BOOL) = ^(BOOL identityOK, BOOL signatureOK, BOOL ipcOK) {
        FKHelperTrustReport *r = [FKHelperTrustReport new];
        r.identityVerified = identityOK;
        r.signatureVerified = signatureOK;
        r.ipcVerified = ipcOK;
        return r;
    };

    // GATE801：Helper 不存在（无报告）且证据缺失，拒绝真实操作。
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
        [failures addObject:@"GATE801 Helper 不存在时应拒绝"];
    }

    // GATE802：发布清单未验证（unavailable），即使身份/签名/IPC 齐备也阻断。
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

    // GATE803：身份 Unknown，拒绝。
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
    if (![gateIdentity.status isEqualToString:@"blocked"]) [failures addObject:@"GATE803 身份 Unknown 时应拒绝"];

    // GATE804：完整性 Unknown，拒绝。
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
    if (![gateIntegrity.status isEqualToString:@"blocked"]) [failures addObject:@"GATE804 完整性 Unknown 时应拒绝"];

    // GATE805：IPC Unavailable，拒绝。
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
    if (![gateIPC.status isEqualToString:@"blocked"]) [failures addObject:@"GATE805 IPC Unavailable 时应拒绝"];

    // GATE806：对端未验证（通道/对端证据缺失），拒绝。
    FKHelperTrustReport *peerUnverified = makeReport(YES, YES, NO);
    FKOperationEligibility *gatePeer = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                           appBundleID:@"com.test.app"
                                                                            operation:FKOperationTypeEnable
                                                                        environmentOK:YES
                                                                     injectorCompatible:YES
                                                                             injector:@"libhooker"
                                                                         helperReport:peerUnverified
                                                                      backupAvailable:YES
                                                                         backupValid:YES
                                                                           scopeClear:YES
                                                                        auditWritable:YES
                                                                      userAuthorized:YES];
    if (![gatePeer.status isEqualToString:@"blocked"]) [failures addObject:@"GATE806 对端未验证时应拒绝"];

    // GATE807：未知 / 写能力必须被能力评估器拒绝。
    FKCapabilityEvaluator *evaluator = [FKCapabilityEvaluator new];
    FKHelperCapabilities *caps = [FKHelperCapabilities capabilitiesWithSet:[NSSet setWithArray:@[@"plugin.list"]]];
    if ([evaluator canPerformCapability:@"plugin.delete" trustReport:peerUnverified capabilities:caps]) {
        [failures addObject:@"GATE807 未知/写能力必须被拒绝"];
    }

    // GATE808：Mock 握手 / 模拟客户端不得被报告为真实连接。
    FKMockHelperClient *mockClient = [[FKMockHelperClient alloc] init];
    if (!mockClient.isMock) [failures addObject:@"GATE808 模拟客户端必须标注 isMock"];
    __block NSDictionary *mockInfo = nil;
    [mockClient requestHelperInfo:^(NSDictionary *_Nullable result, NSError *_Nullable error) {
        (void)error; mockInfo = result;
    }];
    if (![mockInfo[@"mock"] boolValue]) [failures addObject:@"GATE808 模拟 Helper 信息必须携带 mock 标记"];
    FKHelperTestTransport *mockTransport = [[FKHelperTestTransport alloc] init];
    if (!mockTransport.isMock || mockTransport.connected) [failures addObject:@"GATE808 测试传输必须标注 Mock 且未连接"];

    // GATE809：所有模拟条件通过，仍不得获得真实写权限（停留在 preview_only）。
    FKHelperTrustReport *simulated = makeReport(YES, YES, YES);
    simulated.manifestStatus = @"verified";
    simulated.integrityStatus = FKHelperIntegrityVerified;
    FKOperationEligibility *simulatedEligibility = [FKOperationPreflight evaluateOperationForPlugin:plugin
                                                                           appBundleID:@"com.test.app"
                                                                            operation:FKOperationTypeEnable
                                                                        environmentOK:YES
                                                                     injectorCompatible:YES
                                                                             injector:@"libhooker"
                                                                         helperReport:simulated
                                                                      backupAvailable:YES
                                                                         backupValid:YES
                                                                           scopeClear:YES
                                                                        auditWritable:YES
                                                                      userAuthorized:YES];
    if (![simulatedEligibility.mode isEqualToString:@"preview_only"] ||
        simulatedEligibility.decision == FKOperationDecisionAllowed ||
        [simulatedEligibility.status isEqualToString:@"ready"]) {
        [failures addObject:@"GATE809 模拟齐备仍不得放行真实操作"];
    }

    // GATE810：断开连接后撤销相关能力；未连接时只读请求应返回错误。
    [mockTransport disconnect];
    if (mockTransport.status.state != FKHelperTransportStateDisconnected || mockTransport.connected) {
        [failures addObject:@"GATE810 断开后应进入 Disconnected 且不处于已连接"];
    }
    FKHelperReadOnlyClient *offlineClient = [[FKHelperReadOnlyClient alloc] initWithTransport:nil];
    __block NSError *offlineError = nil;
    [offlineClient requestPluginList:^(NSArray *_Nullable plugins, NSError *_Nullable error) {
        (void)plugins; offlineError = error;
    }];
    if (offlineError == nil) [failures addObject:@"GATE810 断开/未连接时请求应返回错误"];

    return failures.copy;
}

@end
