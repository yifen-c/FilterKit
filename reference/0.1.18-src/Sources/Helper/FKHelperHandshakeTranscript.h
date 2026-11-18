#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// 握手转录摘要；将双方身份、随机数、协商版本和只读能力绑定为单一摘要。
@interface FKHelperHandshakeTranscript : NSObject
/// 输入字段必须完整；能力仅接受已知只读白名单且不得重复。
- (nullable NSData *)canonicalDataWithFields:(NSDictionary *)fields;
/// 返回规范转录的 SHA-256 小写十六进制摘要。
- (nullable NSString *)digestForFields:(NSDictionary *)fields;
/// 固定长度比较摘要，拒绝格式错误。
- (BOOL)verifyFields:(NSDictionary *)fields expectedDigest:(NSString *)expectedDigest;
@end
NS_ASSUME_NONNULL_END
