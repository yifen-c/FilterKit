#import "FKHelperPermissionVerifier.h"
#import "FKHelperProtocol.h"

@implementation FKHelperPermissionVerifier

+ (BOOL)verifyPermissionForOperationName:(NSString *)operationName reasons:(NSMutableArray<NSString *> *)reasons {
    if (!FKHelperOperationIsAllowed(operationName)) {
        [reasons addObject:@"操作不在 Helper 白名单内，拒绝授权"];
        return NO;
    }
    // 规则层面操作属白名单；但尚未与真实 Helper 核对授权上下文，保守不判为权限已验证。
    [reasons addObject:@"未与真实 Helper 核对授权上下文，权限模型暂不可视为已验证"];
    return NO;
}

@end
