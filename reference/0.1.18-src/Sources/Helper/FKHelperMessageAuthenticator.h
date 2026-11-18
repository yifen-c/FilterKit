#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 消息认证结果；认证仅证明持有会话密钥，不替代 Helper 身份验证。
@interface FKHelperMessageAuthenticationResult : NSObject
@property (nonatomic, assign, readonly) BOOL valid;
@property (nonatomic, copy, readonly) NSString *keyID;
@property (nonatomic, copy, readonly) NSString *reasonCode;
@end

/// HMAC-SHA256 消息认证。密钥由已验证握手层注入，仅在内存使用，不负责生成或持久化密钥。
@interface FKHelperMessageAuthenticator : NSObject
/// 对原始报文与会话标识进行域分离认证，返回小写十六进制签名。
- (nullable NSString *)signatureForData:(NSData *)data
                              sessionID:(NSString *)sessionID
                                   keyID:(NSString *)keyID
                                     key:(NSData *)key;
/// 固定长度逐字节比较签名；密钥不足 256 bit、会话或签名格式非法时拒绝。
- (FKHelperMessageAuthenticationResult *)verifyData:(NSData *)data
                                           sessionID:(NSString *)sessionID
                                                 key:(NSData *)key
                                          keyID:(NSString *)keyID
                                       signature:(NSString *)signature;
@end

NS_ASSUME_NONNULL_END
