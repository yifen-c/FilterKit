#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// HKDF-SHA256 会话密钥派生；调用方必须先完成可信 Peer 验证。
@interface FKHelperKeyDerivation : NSObject
/// RFC 5869 HKDF；输入密钥至少 32 字节，输出长度为 1…8160 字节。
- (nullable NSData *)deriveKeyFromInputKey:(NSData *)inputKey salt:(NSData *)salt info:(NSData *)info outputLength:(NSUInteger)outputLength;
/// 绑定双方随机数、身份和协议版本，派生独立会话密钥。
- (nullable NSData *)deriveSessionKeyFromInputKey:(NSData *)inputKey clientNonce:(NSString *)clientNonce helperNonce:(NSString *)helperNonce peerID:(NSString *)peerID protocolMajor:(NSInteger)major protocolMinor:(NSInteger)minor;
@end
NS_ASSUME_NONNULL_END
