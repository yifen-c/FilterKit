#import <Foundation/Foundation.h>

/// 准入与协议最小测试：核对非法请求被拒绝、未授权 / 未验证条件下闸门不放行。
@interface FKOperationTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数（与 runChecks 中的检查项一一对应）。
+ (NSUInteger)checkCount;

@end
