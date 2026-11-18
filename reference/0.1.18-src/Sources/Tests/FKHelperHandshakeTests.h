#import <Foundation/Foundation.h>

/// 握手与会话测试（HSK901–912）：报文缺失、RequestID/Nonce/时间戳、协议版本、身份、清单、
/// 对端、未知能力拒绝；齐备校验通过；会话状态流转与断开撤销授权。
@interface FKHelperHandshakeTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
