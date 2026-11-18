#import <Foundation/Foundation.h>

/// v1 协议模型测试（PRO801–812）：报文序列化/反序列化、版本与请求标识校验、
/// 大小与方法白名单、Nonce 防重放、过期窗口、错误码与请求响应匹配。
@interface FKHelperProtocolTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
