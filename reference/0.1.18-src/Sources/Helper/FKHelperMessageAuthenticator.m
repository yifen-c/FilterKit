#import "FKHelperMessageAuthenticator.h"
#import <CommonCrypto/CommonHMAC.h>
#import <string.h>

@interface FKHelperMessageAuthenticationResult ()
@property (nonatomic, assign, readwrite) BOOL valid;
@property (nonatomic, copy, readwrite) NSString *keyID;
@property (nonatomic, copy, readwrite) NSString *reasonCode;
@end

@implementation FKHelperMessageAuthenticationResult
@end

@implementation FKHelperMessageAuthenticator

- (NSString *)signatureForData:(NSData *)data sessionID:(NSString *)sessionID keyID:(NSString *)keyID key:(NSData *)key {
    if (![data isKindOfClass:NSData.class] || data.length == 0 ||
        ![sessionID isKindOfClass:NSString.class] || sessionID.length == 0 || sessionID.length > 128 ||
        ![keyID isKindOfClass:NSString.class] || keyID.length == 0 || keyID.length > 128 ||
        ![key isKindOfClass:NSData.class] || key.length < 32 ||
        data.length > 1024 * 1024) return nil;

    // 会话标识参与 MAC，避免同一报文跨会话复用。
    NSMutableData *authenticated = [NSMutableData data];
    NSData *domain = [@"FilterKit.Helper.Message.v1" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *session = [sessionID dataUsingEncoding:NSUTF8StringEncoding];
    NSData *identifier = [keyID dataUsingEncoding:NSUTF8StringEncoding];
    if (session.length == 0 || session.length > 128 || identifier.length == 0 || identifier.length > 128) return nil;
    [authenticated appendData:domain];
    uint32_t sessionLength = CFSwapInt32HostToBig((uint32_t)session.length);
    uint32_t keyIDLength = CFSwapInt32HostToBig((uint32_t)identifier.length);
    [authenticated appendBytes:&sessionLength length:sizeof(sessionLength)];
    [authenticated appendData:session];
    [authenticated appendBytes:&keyIDLength length:sizeof(keyIDLength)];
    [authenticated appendData:identifier];
    [authenticated appendData:data];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH] = {0};
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, authenticated.bytes, authenticated.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [hex appendFormat:@"%02x", digest[i]];
    memset(digest, 0, sizeof(digest));
    return hex.copy;
}

- (FKHelperMessageAuthenticationResult *)verifyData:(NSData *)data sessionID:(NSString *)sessionID key:(NSData *)key keyID:(NSString *)keyID signature:(NSString *)signature {
    FKHelperMessageAuthenticationResult *result = [FKHelperMessageAuthenticationResult new];
    result.keyID = [keyID isKindOfClass:NSString.class] ? [keyID copy] : @"";
    NSString *expected = [self signatureForData:data sessionID:sessionID keyID:keyID key:key];
    NSData *expectedBytes = [expected dataUsingEncoding:NSUTF8StringEncoding];
    NSData *providedBytes = [signature isKindOfClass:NSString.class] ? [signature dataUsingEncoding:NSUTF8StringEncoding] : nil;
    if (expectedBytes.length != 64 || providedBytes.length != 64) {
        result.valid = NO; result.reasonCode = @"invalid_authentication_input"; return result;
    }
    const uint8_t *expectedBuffer = expectedBytes.bytes;
    const uint8_t *providedBuffer = providedBytes.bytes;
    uint32_t mismatch = 0;
    for (NSUInteger i = 0; i < 64; i++) {
        uint8_t value = providedBuffer[i];
        // 固定遍历全部字节；仅接受小写十六进制。
        uint32_t digit = (uint32_t)(value >= '0' && value <= '9');
        uint32_t alpha = (uint32_t)(value >= 'a' && value <= 'f');
        mismatch |= (uint32_t)(expectedBuffer[i] ^ value);
        mismatch |= (digit | alpha) ^ 1U;
    }
    result.valid = (mismatch == 0);
    result.reasonCode = result.valid ? @"verified" : @"signature_mismatch";
    return result;
}
@end
