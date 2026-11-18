#import <Foundation/Foundation.h>

/// 请求路由测试（RTE901–910）：未知方法、写方法拒绝；白名单方法通过；
/// 请求标识缺失 / 非请求消息拒绝；无 Provider 时不伪造真实数据。
@interface FKHelperRouterTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
