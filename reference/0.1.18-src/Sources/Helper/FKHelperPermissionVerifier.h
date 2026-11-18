#import <Foundation/Foundation.h>

/// Helper 权限模型校验：App 只读请求、Client 受控请求、Helper 仅执行白名单操作。
/// 不接受任意 shell 命令、任意路径、任意脚本、任意文件覆盖与未声明操作类型。
@interface FKHelperPermissionVerifier : NSObject

/// 校验操作是否落在白名单权限内。reasons 追加说明；返回权限模型是否可视为已验证。
+ (BOOL)verifyPermissionForOperationName:(NSString *)operationName reasons:(NSMutableArray<NSString *> *)reasons;

@end
