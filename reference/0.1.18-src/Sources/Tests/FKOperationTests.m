#import "FKOperationTests.h"
#import "FKHelperProtocol.h"
#import "FKHelperTrust.h"
#import "FKOperationGate.h"
#import "FKOperationEligibility.h"
#import "FKManageModels.h"
#import "FKIPCRequest.h"
#import "FKOperationTransaction.h"
#import "FKOperationVerifier.h"
#import "FKOperationRollback.h"
#import "FKConfigurationBackup.h"
#import "FKHelperConnection.h"

@implementation FKOperationTests

+ (NSUInteger)checkCount { return 13; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSError *error = nil;

    // 1. 合法白名单请求通过结构校验。
    NSDictionary *valid = @{
        @"protocol_version": @(FKHelperProtocolVersion),
        @"request_id": @"req-test-1",
        @"operation": FKHelperOperationNameGetStatus,
        @"plugin_id": @"com.test.example:example",
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"nonce": @"nonce-test"
    };
    if (!FKHelperValidateRequest(valid, &error)) [failures addObject:@"合法白名单请求应通过校验"];

    // 2. 未知操作应被拒绝。
    NSMutableDictionary *badOp = [valid mutableCopy];
    badOp[@"operation"] = @"run_arbitrary_command";
    if (FKHelperValidateRequest(badOp, &error)) [failures addObject:@"未知操作应被拒绝"];

    // 3. 协议版本不兼容应被拒绝。
    NSMutableDictionary *badVersion = [valid mutableCopy];
    badVersion[@"protocol_version"] = @(999);
    if (FKHelperValidateRequest(badVersion, &error)) [failures addObject:@"版本不兼容请求应被拒绝"];

    // 4. 缺少插件 ID 应被拒绝。
    NSMutableDictionary *badPlugin = [valid mutableCopy];
    badPlugin[@"plugin_id"] = @"";
    if (FKHelperValidateRequest(badPlugin, &error)) [failures addObject:@"缺少插件 ID 应被拒绝"];

    // 5. 未授权、Helper 未验证、环境与注入器证据不足时，闸门不放行。
    FKPluginModel *plugin = [FKPluginModel modelWithDictionary:@{@"PluginID": @"com.test.example:example", @"Name": @"Example"}];
    FKOperationEligibility *eligibility = [FKOperationPreflight eligibilityForPlugin:plugin
                                                                          operation:FKOperationTypeValidate
                                                                     environmentOK:NO
                                                                  injectorCompatible:NO
                                                                       helperReport:nil
                                                                    backupAvailable:NO
                                                                     userAuthorized:NO];
    if (eligibility.eligible) [failures addObject:@"未授权且证据不足时不应具备操作资格"];
    if (![eligibility.status isEqualToString:@"blocked"]) [failures addObject:@"存在阻断条件时状态应为 blocked"];
    if (![eligibility.mode isEqualToString:@"preview_only"]) [failures addObject:@"0.1.15 操作模式应为 preview_only"];

    // 6. IPC 请求模型序列化后结构合法。
    FKIPCRequest *request = [FKIPCRequest requestWithPluginID:plugin.pluginID operation:FKHelperOperationNameGetStatus];
    if (![request validateWithError:&error]) [failures addObject:@"IPC 请求模型应通过本地校验"];

    // 7. 事务状态机：Created → Preflight 合法；跨级直跳 Completed 应被拒绝。
    FKOperationRequest *opReq = [FKOperationRequest requestWithPluginID:plugin.pluginID operation:FKOperationTypeValidate];
    FKOperationTransaction *transaction = [FKOperationTransaction transactionWithRequest:opReq];
    NSError *smError = nil;
    if (![transaction.stateMachine transitionTo:FKOperationTransactionStatePreflight error:&smError]) {
        [failures addObject:@"状态机 Created→Preflight 流转应合法"];
    }
    if ([transaction.stateMachine transitionTo:FKOperationTransactionStateCompleted error:&smError]) {
        [failures addObject:@"状态机跨级直跳 Completed 应被拒绝"];
    }

    // 8. 结果验证器：一致通过 / 证据不足未知 / 不一致失败。
    if ([FKOperationVerifier verifyTargetState:@"enabled" actualState:@"enabled"] != FKVerificationStatusPassed) {
        [failures addObject:@"目标与实际配置一致时应判为验证通过"];
    }
    if ([FKOperationVerifier verifyTargetState:@"enabled" actualState:@"unknown"] != FKVerificationStatusUnknown) {
        [failures addObject:@"实际配置证据不足时应归为未知"];
    }
    if ([FKOperationVerifier verifyTargetState:@"enabled" actualState:@"disabled"] != FKVerificationStatusFailed) {
        [failures addObject:@"目标与实际配置不一致时应判为验证未通过"];
    }

    // 9. 回滚计划：未产生变更无需回滚；有变更但缺备份应判缺少备份。
    FKOperationRollback *plan = [FKOperationRollback planForTransaction:transaction
                                                         backupAvailable:NO backupValid:NO targetIdentityMatch:YES];
    if (plan.status != FKRollbackStatusNotRequired) [failures addObject:@"未产生变更时应无需回滚"];
    transaction.afterState = @"enabled";
    FKOperationRollback *planMissing = [FKOperationRollback planForTransaction:transaction
                                                                backupAvailable:NO backupValid:NO targetIdentityMatch:YES];
    if (planMissing.status != FKRollbackStatusBackupMissing) [failures addObject:@"缺少操作前备份时应判无法安全回滚"];

    // 10. 配置备份快照序列化与反序列化往返一致。
    FKConfigurationBackup *backup = [FKConfigurationBackup backupWithPluginID:plugin.pluginID
                                                                 injectorType:nil
                                                           targetAppBundleID:nil
                                                                 operationID:nil
                                                        originalConfiguration:@{@"bundles": @[plugin.pluginID]}];
    FKConfigurationBackup *restored = [FKConfigurationBackup backupFromDictionary:backup.JSONDictionary];
    if (!restored || ![restored.pluginID isEqualToString:plugin.pluginID]) {
        [failures addObject:@"配置备份快照往返序列化应保留插件 ID"];
    }

    // 11. Helper 连接抽象在无可信端点证据下默认不可用。
    FKHelperConnection *connection = [FKHelperConnection new];
    if (connection.available) [failures addObject:@"0.1.15 Helper 连接应默认不可用"];

    return failures.copy;
}

@end
