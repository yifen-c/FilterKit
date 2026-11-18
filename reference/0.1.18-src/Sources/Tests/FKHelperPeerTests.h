#import <Foundation/Foundation.h>

/// 对端身份验证测试（PEER901–908）：未连接、身份缺失、标识不符、Build 不符、清单不可信、
/// 可信对端、会话变化重新验证、断开撤销结论。
@interface FKHelperPeerTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
