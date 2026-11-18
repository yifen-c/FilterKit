#import "FKOperationModels.h"

/// 统一的时间格式化，供审计记录与备份清单使用。
static NSString *FKOperationTimestamp(NSDate *date) {
    if (!date) return @"";
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter stringFromDate:date];
}

@implementation FKPluginState

+ (NSString *)statusText:(FKPluginStatus)status {
    switch (status) {
        case FKPluginStatusEnabled: return @"已启用";
        case FKPluginStatusDisabled: return @"已停用";
        case FKPluginStatusPartiallyEnabled: return @"部分启用";
        case FKPluginStatusPending: return @"操作中";
        case FKPluginStatusFailed: return @"操作失败";
        case FKPluginStatusUnsupported: return @"不支持";
        case FKPluginStatusUnknown:
        default: return @"未知";
    }
}

+ (NSString *)associationText:(FKPluginAssociationState)status {
    switch (status) {
        case FKPluginAssociationStateAssociated: return @"已关联";
        case FKPluginAssociationStateNotAssociated: return @"未关联";
        case FKPluginAssociationStateUnknown:
        default: return @"未确认";
    }
}

+ (NSString *)configurationText:(FKConfigurationStatus)status {
    switch (status) {
        case FKConfigurationStatusEnabled: return @"已启用";
        case FKConfigurationStatusDisabled: return @"已禁用";
        case FKConfigurationStatusUnknown:
        default: return @"未确认";
    }
}

+ (NSString *)runtimeText:(FKRuntimeStatus)status {
    switch (status) {
        case FKRuntimeStatusNotRunning: return @"未运行";
        case FKRuntimeStatusRunning: return @"运行中";
        case FKRuntimeStatusLoaded: return @"已加载";
        case FKRuntimeStatusNotLoaded: return @"未加载";
        case FKRuntimeStatusUnknown:
        default: return @"未确认";
    }
}

+ (NSString *)backupText:(FKPluginBackupStatus)status {
    switch (status) {
        case FKPluginBackupStatusNone: return @"未备份";
        case FKPluginBackupStatusBackedUp: return @"已备份";
        case FKPluginBackupStatusFailed: return @"备份失败";
        case FKPluginBackupStatusUnknown:
        default: return @"未检查";
    }
}

static NSString *FKAssociationCode(FKPluginAssociationState status) {
    switch (status) {
        case FKPluginAssociationStateAssociated: return @"associated";
        case FKPluginAssociationStateNotAssociated: return @"not_associated";
        case FKPluginAssociationStateUnknown:
        default: return @"unknown";
    }
}

static NSString *FKConfigurationCode(FKConfigurationStatus status) {
    switch (status) {
        case FKConfigurationStatusEnabled: return @"enabled";
        case FKConfigurationStatusDisabled: return @"disabled";
        case FKConfigurationStatusUnknown:
        default: return @"unknown";
    }
}

static NSString *FKRuntimeCode(FKRuntimeStatus status) {
    switch (status) {
        case FKRuntimeStatusNotRunning: return @"not_running";
        case FKRuntimeStatusRunning: return @"running";
        case FKRuntimeStatusLoaded: return @"loaded";
        case FKRuntimeStatusNotLoaded: return @"not_loaded";
        case FKRuntimeStatusUnknown:
        default: return @"unknown";
    }
}

static NSString *FKBackupCode(FKPluginBackupStatus status) {
    switch (status) {
        case FKPluginBackupStatusNone: return @"none";
        case FKPluginBackupStatusBackedUp: return @"backed_up";
        case FKPluginBackupStatusFailed: return @"failed";
        case FKPluginBackupStatusUnknown:
        default: return @"unknown";
    }
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"plugin_id": self.pluginID ?: @"",
        @"app_bundle_id": self.appBundleID ?: @"",
        @"status": [FKPluginState statusText:self.status],
        @"supported": @(self.supported),
        @"evidence": self.evidence ?: @"",
        @"injector": self.injector ?: @"",
        @"unsupported_reason": self.unsupportedReason ?: @"",
        @"association_status": FKAssociationCode(self.associationStatus),
        @"association_text": [FKPluginState associationText:self.associationStatus],
        @"configuration_status": FKConfigurationCode(self.configurationStatus),
        @"configuration_text": [FKPluginState configurationText:self.configurationStatus],
        @"runtime_status": FKRuntimeCode(self.runtimeStatus),
        @"runtime_text": [FKPluginState runtimeText:self.runtimeStatus],
        @"compatibility_status": self.compatibilityStatus ?: @"",
        @"backup_status": FKBackupCode(self.backupStatus),
        @"backup_text": [FKPluginState backupText:self.backupStatus],
        @"last_operation_id": self.lastOperationID ?: @"",
        @"last_verified_at": FKOperationTimestamp(self.lastVerifiedAt) ?: @"",
        @"last_checked": FKOperationTimestamp(self.lastChecked) ?: @""
    };
}

@end

@implementation FKOperationRequest

+ (instancetype)requestWithPluginID:(NSString *)pluginID operation:(FKOperationType)operation {
    return [self requestWithPluginID:pluginID appBundleID:nil operation:operation];
}

+ (instancetype)requestWithPluginID:(NSString *)pluginID
                          appBundleID:(nullable NSString *)appBundleID
                           operation:(FKOperationType)operation {
    FKOperationRequest *request = [FKOperationRequest new];
    request.requestID = [NSUUID UUID].UUIDString;
    request.pluginID = pluginID ?: @"";
    request.appBundleID = appBundleID;
    if (appBundleID.length) {
        request.targetAppBundleIDs = @[appBundleID];
    }
    request.operation = operation;
    request.createdAt = [NSDate date];
    return request;
}

+ (NSString *)operationText:(FKOperationType)operation {
    switch (operation) {
        case FKOperationTypeEnable: return @"enable";
        case FKOperationTypeDisable: return @"disable";
        case FKOperationTypeValidate: return @"validate";
        case FKOperationTypeRestore: return @"restore";
        default: return @"";
    }
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"request_id": self.requestID ?: @"",
        @"plugin_id": self.pluginID ?: @"",
        @"app_bundle_id": self.appBundleID ?: @"",
        @"target_app_bundle_ids": self.targetAppBundleIDs ?: @[],
        @"operation": [FKOperationRequest operationText:self.operation],
        @"reason": self.reason ?: @"",
        @"backup_id": self.backupID ?: @"",
        @"authorization": self.authorization ?: @"",
        @"created_at": FKOperationTimestamp(self.createdAt) ?: @""
    };
}

@end

@implementation FKOperationResult

+ (instancetype)resultWithRequestID:(NSString *)requestID success:(BOOL)success
                          errorCode:(NSString *)errorCode message:(NSString *)message {
    FKOperationResult *result = [FKOperationResult new];
    result.requestID = requestID ?: @"";
    result.success = success;
    result.errorCode = errorCode ?: @"";
    result.message = message ?: @"";
    result.completedAt = [NSDate date];
    result.decision = FKOperationDecisionUnknown;
    return result;
}

static NSString *FKDecisionCode(FKOperationDecision decision) {
    switch (decision) {
        case FKOperationDecisionAllowed: return @"allowed";
        case FKOperationDecisionDenied: return @"denied";
        case FKOperationDecisionNeedsConfirmation: return @"needs_confirmation";
        case FKOperationDecisionUnsupported: return @"unsupported";
        case FKOperationDecisionUnknown:
        default: return @"unknown";
    }
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"request_id": self.requestID ?: @"",
        @"success": @(self.success),
        @"error_code": self.errorCode ?: @"",
        @"message": self.message ?: @"",
        @"decision": FKDecisionCode(self.decision),
        @"previous_state": self.previousState ?: @"",
        @"current_state": self.currentState ?: @"",
        @"before_state": self.beforeState ?: @"",
        @"target_state": self.targetState ?: @"",
        @"after_state": self.afterState ?: @"",
        @"before_hash": self.beforeHash ?: @"",
        @"after_hash": self.afterHash ?: @"",
        @"verification_result": self.verificationResult ?: @"none",
        @"rollback_result": self.rollbackResult ?: @"none",
        @"failure_reason": self.failureReason ?: @"",
        @"helper_identity": self.helperIdentity ?: @"",
        @"helper_version": self.helperVersion ?: @"",
        @"protocol_version": self.protocolVersion ?: @"",
        @"backup_id": self.backupID ?: @"",
        @"completed_at": FKOperationTimestamp(self.completedAt) ?: @""
    };
}

@end

@implementation FKOperationRecord

+ (instancetype)recordFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKOperationRecord *record = [self new];
    record.operationID = dict[@"operation_id"] ?: @"";
    record.pluginID = dict[@"plugin_id"] ?: @"";
    record.operation = dict[@"operation"] ?: @"";
    record.previousState = dict[@"previous_state"] ?: @"";
    record.currentState = dict[@"current_state"] ?: @"";
    record.result = dict[@"result"] ?: @"";
    record.verification = dict[@"verification"] ?: @"none";
    record.backupID = dict[@"backup_id"] ?: @"";
    record.errorMessage = dict[@"error_message"] ?: @"";
    record.mode = dict[@"mode"] ?: @"preview_only";
    record.helperStatus = dict[@"helper_status"] ?: @"unverified";
    if ([dict[@"checks"] isKindOfClass:NSArray.class]) record.checks = dict[@"checks"];
    if ([dict[@"reasons"] isKindOfClass:NSArray.class]) record.reasons = dict[@"reasons"];
    // 0.1.15 扩展字段；旧记录缺失时回落空值/默认值。
    record.appBundleID = dict[@"app_bundle_id"] ?: nil;
    record.helperIdentity = dict[@"helper_identity"] ?: nil;
    record.helperVersion = dict[@"helper_version"] ?: nil;
    record.protocolVersion = dict[@"protocol_version"] ?: nil;
    record.beforeState = dict[@"before_state"] ?: nil;
    record.targetState = dict[@"target_state"] ?: nil;
    record.afterState = dict[@"after_state"] ?: nil;
    record.beforeHash = dict[@"before_hash"] ?: nil;
    record.afterHash = dict[@"after_hash"] ?: nil;
    record.authorization = dict[@"authorization"] ?: nil;
    record.gateResult = dict[@"gate_result"] ?: nil;
    record.executionResult = dict[@"execution_result"] ?: nil;
    record.verificationResult = dict[@"verification_result"] ?: nil;
    record.rollbackResult = dict[@"rollback_result"] ?: nil;
    record.failureReason = dict[@"failure_reason"] ?: nil;
    NSString *timestamp = dict[@"timestamp"];
    if ([timestamp isKindOfClass:NSString.class] && timestamp.length) {
        static NSISO8601DateFormatter *formatter;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSISO8601DateFormatter alloc] init];
            formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        });
        record.timestamp = [formatter dateFromString:timestamp];
    }
    return record;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"operation_id": self.operationID ?: @"",
        @"plugin_id": self.pluginID ?: @"",
        @"operation": self.operation ?: @"",
        @"app_bundle_id": self.appBundleID ?: @"",
        @"previous_state": self.previousState ?: @"",
        @"current_state": self.currentState ?: @"",
        @"before_state": self.beforeState ?: @"",
        @"target_state": self.targetState ?: @"",
        @"after_state": self.afterState ?: @"",
        @"result": self.result ?: @"",
        @"verification": self.verification ?: @"none",
        @"verification_result": self.verificationResult ?: @"none",
        @"rollback_result": self.rollbackResult ?: @"none",
        @"backup_id": self.backupID ?: @"",
        @"before_hash": self.beforeHash ?: @"",
        @"after_hash": self.afterHash ?: @"",
        @"authorization": self.authorization ?: @"",
        @"gate_result": self.gateResult ?: @"",
        @"execution_result": self.executionResult ?: @"",
        @"failure_reason": self.failureReason ?: @"",
        @"helper_identity": self.helperIdentity ?: @"",
        @"helper_version": self.helperVersion ?: @"",
        @"protocol_version": self.protocolVersion ?: @"",
        @"timestamp": FKOperationTimestamp(self.timestamp) ?: @"",
        @"error_message": self.errorMessage ?: @"",
        @"mode": self.mode ?: @"preview_only",
        @"checks": self.checks ?: @[],
        @"reasons": self.reasons ?: @[],
        @"helper_status": self.helperStatus ?: @"unverified"
    };
}

@end
