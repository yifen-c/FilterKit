#import "FKHelperConnection.h"
#import "FKHelperTrust.h"
#import "FKOperationModels.h"

NSErrorDomain const FKHelperConnectionErrorDomain = @"FilterKitHelperConnectionError";

@implementation FKHelperConnection

- (BOOL)available {
    // 未取得可信端点、签名链与受支持协议证据前，不认为存在可用 Helper 通道。
    return NO;
}

- (void)verifyConnectionWithCompletion:(void (^)(FKHelperTrustReport *_Nullable))completion {
    // 本地无可信候选证据：返回未发现状态报告，不发起连接探测。
    FKHelperTrustReport *report = [FKHelperTrustReport new];
    report.state = FKHelperTrustStateNotFound;
    report.signatureStatus = FKSignatureStatusUnknown;
    report.identityVerified = NO;
    report.signatureVerified = NO;
    report.permissionVerified = NO;
    report.ipcVerified = NO;
    report.reasons = @[@"0.1.15 未接入已验证身份的 Helper 端点，连接校验停留在未发现状态"];
    report.checkedAt = [NSDate date];
    if (completion) completion(report);
}

- (void)queryPluginState:(NSString *)pluginID
            appBundleID:(nullable NSString *)appBundleID
             completion:(void (^)(FKPluginState *_Nullable, NSError *_Nullable))completion {
    NSError *error = [NSError errorWithDomain:FKHelperConnectionErrorDomain
                                        code:FKHelperConnectionErrorUnavailable
                                    userInfo:@{NSLocalizedDescriptionKey: @"Helper 通道不可用，无法读取插件运行时状态"}];
    FKPluginState *state = [FKPluginState new];
    state.pluginID = pluginID ?: @"";
    state.appBundleID = appBundleID;
    state.status = FKPluginStatusUnknown;
    state.configurationStatus = FKConfigurationStatusUnknown;
    state.runtimeStatus = FKRuntimeStatusUnknown;
    state.associationStatus = FKPluginAssociationStateUnknown;
    state.backupStatus = FKPluginBackupStatusUnknown;
    state.supported = NO;
    state.unsupportedReason = @"无可信 Helper 通道，状态无法由运行时证据确认";
    if (completion) completion(state, error);
}

- (void)applyAuthorizedOperation:(FKOperationRequest *)request
                       completion:(void (^)(FKOperationResult *_Nullable, NSError *_Nullable))completion {
    NSError *error = [NSError errorWithDomain:FKHelperConnectionErrorDomain
                                        code:FKHelperConnectionErrorUnavailable
                                    userInfo:@{NSLocalizedDescriptionKey: @"未检测到身份已验证的 Helper；真实启停暂不开放"}];
    FKOperationResult *result = [FKOperationResult resultWithRequestID:request.requestID ?: @""
                                                              success:NO
                                                            errorCode:@"helper_unavailable"
                                                              message:@"未检测到身份已验证的 RootHelper；真实启停暂不开放"];
    result.decision = FKOperationDecisionDenied;
    result.failureReason = @"Helper 端点未验证或不可用，操作在执行前被安全拒绝";
    result.verificationResult = @"none";
    result.rollbackResult = @"not_required";
    if (completion) completion(result, error);
}

@end
