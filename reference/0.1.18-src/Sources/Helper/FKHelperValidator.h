#import <Foundation/Foundation.h>
#import "FKHelperProtocol.h"

/// Helper 请求的本地预校验：身份、操作白名单、路径边界。纯逻辑校验，不发起任何 IPC。
@interface FKHelperValidator : NSObject

/// Helper 身份是否已通过签名/授权验证。当前版本未接入已验证 Helper，恒为 NO。
@property (nonatomic, assign, readonly) BOOL identityVerified;

/// 校验操作请求：插件 ID 非空且操作在白名单内。
+ (BOOL)validateRequest:(NSString *)pluginID operationName:(NSString *)operationName error:(NSError **)error;

/// 校验目标路径规范化后仍位于可信根目录内，拒绝 ../ 越界与绝对路径逃逸。
+ (BOOL)validateTargetPath:(NSString *)path withinRoot:(NSString *)root error:(NSError **)error;

@end
