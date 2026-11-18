#import <Foundation/Foundation.h>

/// Transport 抽象与只读客户端测试（TRN801–807）：接口完整性、连接/断开/错误/超时状态、
/// 客户端与具体传输解耦，以及 Mock 不得被报告为真实连接。
@interface FKHelperTransportTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
