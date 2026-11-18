#import "FKHelperClient.h"
#import "FKHelperValidator.h"

@implementation FKHelperClient

- (BOOL)available {
    // 身份、签名、权限与 IPC 协议尚未验证前，不认为 Helper 可用。
    return NO;
}

/// 业务操作类型到 Helper 白名单操作的映射。
static FKHelperOperation FKHelperOperationFromRequest(FKOperationType type) {
    switch (type) {
        case FKOperationTypeEnable: return FKHelperOperationEnable;
        case FKOperationTypeDisable: return FKHelperOperationDisable;
        case FKOperationTypeValidate: return FKHelperOperationValidate;
        case FKOperationTypeRestore: return FKHelperOperationRestore;
        default: return FKHelperOperationGetStatus;
    }
}

- (void)performOperation:(FKOperationRequest *)request completion:(void (^)(FKOperationResult *))completion {
    FKOperationResult *result;
    NSString *operationName = FKHelperOperationName(FKHelperOperationFromRequest(request.operation));

    NSError *validationError = nil;
    if (![FKHelperValidator validateRequest:request.pluginID operationName:operationName error:&validationError]) {
        result = [FKOperationResult resultWithRequestID:request.requestID success:NO
                                              errorCode:@"invalid_request" message:validationError.localizedDescription];
    } else if (!self.available) {
        // 未接入已验证 Helper：安全拒绝，不连接、不发命令、不修改系统。
        result = [FKOperationResult resultWithRequestID:request.requestID success:NO
                                              errorCode:@"helper_unavailable"
                                                message:@"未检测到身份已验证的 RootHelper；真实启停暂不开放"];
    } else {
        // 预留：后续在此建立受控 IPC，仅传白名单操作名与插件 ID，由 Helper 重新解析可信路径。
        result = [FKOperationResult resultWithRequestID:request.requestID success:NO
                                              errorCode:@"helper_incompatible"
                                                message:@"当前注入器或插件格式不受支持"];
    }

    if (completion) completion(result);
}

@end
