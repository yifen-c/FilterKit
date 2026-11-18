#import "FKOperationManager.h"
#import "FKPluginManager.h"
#import "FKStateManager.h"
#import "FKAuditManager.h"
#import "FKHelperClient.h"
#import "FKBackupManager.h"
#import "FKManageModels.h"
#import "FKOperationGate.h"
#import "FKOperationEligibility.h"
#import "FKOperationTransaction.h"
#import "FKOperationVerifier.h"
#import "FKOperationRollback.h"

@interface FKOperationManager ()
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKStateManager *stateManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
@property (nonatomic, strong) FKHelperClient *helperClient;
@property (nonatomic, strong) FKBackupManager *backupManager;
@property (nonatomic, strong) NSMutableSet<NSString *> *pendingRequestIDs;
@property (nonatomic, strong) NSLock *lock;
- (instancetype)initWithPluginManager:(FKPluginManager *)pluginManager
                          stateManager:(FKStateManager *)stateManager
                          auditManager:(FKAuditManager *)auditManager
                          helperClient:(FKHelperClient *)helperClient
                        backupManager:(FKBackupManager *)backupManager;
- (void)runOperation:(FKOperationType)operation pluginID:(NSString *)pluginID
          appBundleID:(nullable NSString *)appBundleID completion:(void (^)(FKOperationResult *))completion;
- (void)recordAudit:(FKOperationRequest *)request result:(FKOperationResult *)result
           previous:(NSString *)previousState current:(NSString *)currentState backupID:(NSString *)backupID
             reasons:(NSArray<NSString *> *)reasons checks:(NSArray<NSDictionary *> *)checks
        helperStatus:(NSString *)helperStatus mode:(NSString *)mode;
/// 将门禁检查项转为字典数组，供审计快照落盘。
- (NSArray<NSDictionary *> *)checkDictionaries:(NSArray<FKOperationCheck *> *)checks;
@end

@implementation FKOperationManager

- (instancetype)initWithPluginManager:(FKPluginManager *)pluginManager
                          stateManager:(FKStateManager *)stateManager
                          auditManager:(FKAuditManager *)auditManager
                          helperClient:(FKHelperClient *)helperClient {
    return [self initWithPluginManager:pluginManager stateManager:stateManager
                          auditManager:auditManager helperClient:helperClient backupManager:nil];
}

- (instancetype)initWithPluginManager:(FKPluginManager *)pluginManager
                          stateManager:(FKStateManager *)stateManager
                          auditManager:(FKAuditManager *)auditManager
                          helperClient:(FKHelperClient *)helperClient
                        backupManager:(FKBackupManager *)backupManager {
    if ((self = [super init])) {
        _pluginManager = pluginManager;
        _stateManager = stateManager;
        _auditManager = auditManager;
        _helperClient = helperClient;
        _backupManager = backupManager;
        _pendingRequestIDs = [NSMutableSet set];
        _lock = [NSLock new];
    }
    return self;
}

#pragma mark - 前置检查与预演

- (NSDictionary *)validatePlugin:(NSString *)pluginID {
    return [self evaluatePluginID:pluginID operation:FKOperationTypeValidate];
}

- (NSDictionary *)previewForPluginID:(NSString *)pluginID operation:(FKOperationType)operation {
    NSMutableDictionary *preview = [NSMutableDictionary dictionaryWithDictionary:[self evaluatePluginID:pluginID operation:operation]];
    FKPluginModel *model = [self.pluginManager pluginForID:pluginID];
    FKPluginState *state = [self.stateManager stateForPluginID:pluginID];

    preview[@"target_state"] = operation == FKOperationTypeDisable ? @"disabled" : @"enabled";
    preview[@"current_state"] = state ? [FKPluginState statusText:state.status] : @"未知";
    preview[@"backup_available"] = @(self.backupManager != nil);
    preview[@"risk"] = model.integrity == FKPluginIntegrityAbnormal ? @"高" : @"中";
    preview[@"impact"] = @[
        @"修改受支持的插件状态配置",
        @"不删除 dylib 文件",
        @"不卸载 dpkg 软件包",
        @"不修改其他插件配置"
    ];
    preview[@"note"] = @"尚未执行任何操作；确认后进入受控操作流程";
    return preview.copy;
}

/// 固定前置检查：插件身份 → 兼容性 → 完整性 → 当前状态。
- (NSDictionary *)evaluatePluginID:(NSString *)pluginID operation:(FKOperationType)operation {
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];
    FKPluginModel *model = pluginID.length ? [self.pluginManager pluginForID:pluginID] : nil;
    FKPluginState *state = [self.stateManager stateForPluginID:pluginID];

    if (!model) {
        [reasons addObject:@"插件不存在或未被扫描识别"];
    } else {
        if (!state.supported) [reasons addObject:state.unsupportedReason.length ? state.unsupportedReason : @"当前环境不支持受控管理"];
        if (model.integrity == FKPluginIntegrityAbnormal) [reasons addObject:@"插件文件或配置异常，需先排查完整性"];
        if (state.status == FKPluginStatusPending) [reasons addObject:@"上一次操作尚未完成"];
    }

    BOOL eligible = reasons.count == 0;
    return @{
        @"eligible": @(eligible),
        @"reasons": reasons.copy,
        @"plugin_id": pluginID ?: @"",
        @"operation": [FKOperationRequest operationText:operation],
        @"supported": @(state.supported),
        @"current_status": [FKPluginState statusText:state.status]
    };
}

#pragma mark - 受控操作

- (void)enablePlugin:(NSString *)pluginID completion:(void (^)(FKOperationResult *))completion {
    [self runOperation:FKOperationTypeEnable pluginID:pluginID appBundleID:nil completion:completion];
}

- (void)disablePlugin:(NSString *)pluginID completion:(void (^)(FKOperationResult *))completion {
    [self runOperation:FKOperationTypeDisable pluginID:pluginID appBundleID:nil completion:completion];
}

- (void)restoreOperation:(NSString *)operationID completion:(void (^)(FKOperationResult *))completion {
    FKOperationRecord *record = [self.auditManager recordForID:operationID];
    if (!record) {
        FKOperationResult *result = [FKOperationResult resultWithRequestID:@"" success:NO errorCode:@"record_not_found" message:@"未找到对应操作记录"];
        if (completion) completion(result);
        return;
    }
    [self runOperation:FKOperationTypeRestore pluginID:record.pluginID appBundleID:record.appBundleID completion:completion];
}

- (void)runOperation:(FKOperationType)operation pluginID:(NSString *)pluginID
          appBundleID:(nullable NSString *)appBundleID completion:(void (^)(FKOperationResult *))completion {
    FKOperationRequest *request = [FKOperationRequest requestWithPluginID:pluginID appBundleID:appBundleID operation:operation];

    // 重复请求防护：同一请求 ID 不重复入队。
    [self.lock lock];
    if ([self.pendingRequestIDs containsObject:request.requestID]) {
        [self.lock unlock];
        FKOperationResult *dup = [FKOperationResult resultWithRequestID:request.requestID success:NO errorCode:@"duplicate_request" message:@"重复的操作请求"];
        dup.decision = FKOperationDecisionDenied;
        dup.rollbackResult = @"not_required";
        if (completion) completion(dup);
        return;
    }
    [self.pendingRequestIDs addObject:request.requestID];
    [self.lock unlock];

    // 事务骨架：创建 → 前置检查 → 门禁校验；真实执行通道在条件不满足时安全拒绝。
    FKOperationTransaction *transaction = [FKOperationTransaction transactionWithRequest:request];
    [transaction advanceTo:FKOperationTransactionStatePreflight error:nil];

    FKPluginModel *model = [self.pluginManager pluginForID:pluginID];
    FKPluginState *previous = [self.stateManager stateForPluginID:pluginID];
    NSString *beforeState = previous.configurationStatus != FKConfigurationStatusUnknown
        ? [FKPluginState configurationText:previous.configurationStatus]
        : [FKPluginState statusText:previous.status];
    NSString *targetState = operation == FKOperationTypeDisable ? @"disabled" : @"enabled";

    // 统一 Gate 评估：身份 / App 身份 / Helper 分层 / IPC / 协议 / 范围 / 备份 / 备份校验 / 兼容 / 审计 / 授权。
    FKOperationEligibility *eligibility = [FKOperationPreflight evaluateOperationForPlugin:model
                                                                          appBundleID:appBundleID
                                                                           operation:operation
                                                                       environmentOK:NO
                                                                    injectorCompatible:NO
                                                                            injector:nil
                                                                        helperReport:nil
                                                                     backupAvailable:(self.backupManager != nil)
                                                                         backupValid:NO
                                                                           scopeClear:YES
                                                                        auditWritable:(self.auditManager != nil)
                                                                      userAuthorized:NO];
    transaction.checks = eligibility.checks;
    transaction.reasons = eligibility.blockReasons;
    transaction.decision = eligibility.decision;
    transaction.beforeState = beforeState;
    transaction.targetState = targetState;
    [transaction advanceTo:FKOperationTransactionStateGateChecking error:nil];

    NSArray<NSString *> *reasons = eligibility.blockReasons ?: @[];
    NSArray<NSDictionary *> *checks = [self checkDictionaries:eligibility.checks];
    NSString *helperStatus = self.helperClient.available ? @"verified" : @"unverified";

    BOOL allowed = eligibility.eligible && eligibility.decision == FKOperationDecisionAllowed;
    if (!allowed) {
        // 准入未通过：不进入备份与执行，事务置失败，回滚标记为无需回滚。
        NSString *code = eligibility.reasonCodes.firstObject ?: @"not_eligible";
        FKOperationResult *result = [FKOperationResult resultWithRequestID:request.requestID success:NO
                                                                 errorCode:code
                                                                  message:reasons.count ? [reasons componentsJoinedByString:@"; "] : @"准入条件不满足"];
        result.decision = eligibility.decision;
        result.beforeState = beforeState;
        result.targetState = targetState;
        result.afterState = @"unknown";
        result.verificationResult = @"none";
        result.rollbackResult = @"not_required";
        result.failureReason = reasons.count ? [reasons componentsJoinedByString:@"; "] : @"准入条件不满足，操作在执行前被安全拒绝";
        [transaction advanceTo:FKOperationTransactionStateFailed error:nil];
        transaction.afterState = @"unknown";
        transaction.verificationResult = result.verificationResult;
        transaction.rollbackResult = result.rollbackResult;
        transaction.failureReason = result.failureReason;

        [self recordAudit:request result:result previous:beforeState current:@"未知" backupID:nil
                  reasons:reasons checks:checks helperStatus:helperStatus mode:@"preview_only"];
        [self finishRequest:request.requestID];
        if (completion) completion(result);
        return;
    }

    // 以下分支在 0.1.15 策略下不可达：策略不开放真实操作，Helper 通道亦未验证。
    // 保留既有操作前备份与 Helper 调用兜底；真实环境须先通过 Gate、授权、备份校验与通道验证。
    NSString *backupID = [self.backupManager createOperationBackupForRequest:request];
    request.backupID = backupID;
    transaction.backupID = backupID;
    [transaction advanceTo:FKOperationTransactionStateBackup error:nil];

    [self.helperClient performOperation:request completion:^(FKOperationResult *result) {
        result.beforeState = beforeState;
        result.targetState = targetState;
        result.backupID = backupID;
        result.previousState = beforeState;
        result.currentState = result.success ? targetState : beforeState;
        result.afterState = result.success ? targetState : @"unknown";
        result.verificationResult = result.success ? @"unknown" : @"none";
        result.rollbackResult = @"not_required";
        NSArray<NSString *> *failureReasons = result.success ? @[] : (result.message.length ? @[result.message] : @[]);
        [self recordAudit:request result:result previous:beforeState current:result.currentState backupID:backupID
                  reasons:failureReasons checks:checks helperStatus:helperStatus mode:@"preview_only"];
        [self finishRequest:request.requestID];
        if (completion) completion(result);
    }];
}

- (NSArray<NSDictionary *> *)checkDictionaries:(NSArray<FKOperationCheck *> *)checks {
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    for (FKOperationCheck *check in checks) [items addObject:check.JSONDictionary];
    return items.copy;
}

#pragma mark - 审计与收尾

- (void)recordAudit:(FKOperationRequest *)request result:(FKOperationResult *)result
           previous:(NSString *)previousState current:(NSString *)currentState backupID:(NSString *)backupID
             reasons:(NSArray<NSString *> *)reasons checks:(NSArray<NSDictionary *> *)checks
        helperStatus:(NSString *)helperStatus mode:(NSString *)mode {
    FKOperationRecord *record = [FKOperationRecord new];
    record.operationID = request.requestID;
    record.pluginID = request.pluginID;
    record.operation = [FKOperationRequest operationText:request.operation];
    record.appBundleID = request.appBundleID;
    record.previousState = previousState ?: @"";
    record.currentState = currentState ?: @"";
    record.beforeState = result.beforeState ?: previousState ?: @"";
    record.targetState = result.targetState ?: @"";
    record.afterState = result.afterState ?: currentState ?: @"";
    record.beforeHash = result.beforeHash ?: @"";
    record.afterHash = result.afterHash ?: @"";
    record.result = result.success ? @"success" : @"failed";
    record.verification = result.verificationResult.length ? result.verificationResult : (result.success ? @"passed" : @"pending");
    record.verificationResult = result.verificationResult ?: @"none";
    record.rollbackResult = result.rollbackResult ?: @"not_required";
    record.backupID = backupID ?: @"";
    record.timestamp = [NSDate date];
    record.errorMessage = result.message ?: @"";
    record.failureReason = result.failureReason ?: @"";
    record.helperIdentity = result.helperIdentity ?: @"";
    record.helperVersion = result.helperVersion ?: @"";
    record.protocolVersion = result.protocolVersion ?: @"";
    record.mode = mode.length ? mode : @"preview_only";
    record.reasons = reasons ?: @[];
    record.checks = checks ?: @[];
    record.helperStatus = helperStatus.length ? helperStatus : @"unverified";
    [self.auditManager appendRecord:record];
}

- (void)finishRequest:(NSString *)requestID {
    [self.lock lock];
    [self.pendingRequestIDs removeObject:requestID];
    [self.lock unlock];
}

@end
