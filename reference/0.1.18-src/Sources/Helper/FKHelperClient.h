#import <Foundation/Foundation.h>
#import "FKOperationModels.h"
#import "FKHelperProtocol.h"

@class FKHelperValidator;

/// 受控 Helper 客户端。主 App 不直接执行系统命令，统一经此客户端向 Helper 提交白名单操作。
/// 0.1.2 尚未接入已验证身份、签名与 IPC 通道，available 恒为 NO；所有真实操作在此被安全拒绝。
@interface FKHelperClient : NSObject

/// 是否存在可用且身份已验证的 Helper。当前版本恒为 NO。
@property (nonatomic, assign, readonly) BOOL available;

/// 提交白名单操作。不接受任意命令字符串；Helper 依据插件 ID 从可信数据重新解析路径。
- (void)performOperation:(FKOperationRequest *)request completion:(void (^)(FKOperationResult *result))completion;

@end
