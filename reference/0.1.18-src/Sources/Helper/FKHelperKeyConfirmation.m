#import "FKHelperKeyConfirmation.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CoreFoundation/CoreFoundation.h>
#import <string.h>

@implementation FKHelperKeyConfirmation

- (NSString *)proofForRole:(FKHelperConfirmationRole)role
                 sessionID:(NSString *)sessionID
           transcriptDigest:(NSString *)transcriptDigest
                        key:(NSData *)key {
    if ((role != FKHelperConfirmationRoleClient && role != FKHelperConfirmationRoleHelper) ||
        ![sessionID isKindOfClass:NSString.class] || sessionID.length == 0 || sessionID.length > 128 ||
        ![transcriptDigest isKindOfClass:NSString.class] || transcriptDigest.length != 64 ||
        ![key isKindOfClass:NSData.class] || key.length < 32) return nil;

    NSData *digestData = [transcriptDigest dataUsingEncoding:NSASCIIStringEncoding];
    const char *digestText = transcriptDigest.UTF8String;
    if (digestData.length != 64 || digestText == NULL) return nil;
    for (NSUInteger i = 0; i < 64; i++) {
        char c = digestText[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return nil;
    }
    NSData *sessionData = [sessionID dataUsingEncoding:NSUTF8StringEncoding];
    NSData *roleData = [(role == FKHelperConfirmationRoleClient ? @"client" : @"helper") dataUsingEncoding:NSUTF8StringEncoding];
    NSData *domain = [@"FilterKit.Helper.KeyConfirmation.v1" dataUsingEncoding:NSUTF8StringEncoding];
    uint32_t sessionLength = CFSwapInt32HostToBig((uint32_t)sessionData.length);
    NSMutableData *input = [NSMutableData dataWithData:domain];
    [input appendBytes:&sessionLength length:sizeof(sessionLength)];
    [input appendData:sessionData];
    [input appendData:roleData];
    [input appendData:digestData];

    uint8_t mac[CC_SHA256_DIGEST_LENGTH] = {0};
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, input.bytes, input.length, mac);
    NSMutableString *hex = [NSMutableString stringWithCapacity:64];
    for (NSUInteger i = 0; i < sizeof(mac); i++) [hex appendFormat:@"%02x", mac[i]];
    memset(mac, 0, sizeof(mac));
    if (input.length) memset(input.mutableBytes, 0, input.length);
    return hex.copy;
}

- (BOOL)verifyProof:(NSString *)proof role:(FKHelperConfirmationRole)role
          sessionID:(NSString *)sessionID transcriptDigest:(NSString *)transcriptDigest key:(NSData *)key {
    NSString *expected = [self proofForRole:role sessionID:sessionID transcriptDigest:transcriptDigest key:key];
    if (expected.length != 64 || ![proof isKindOfClass:NSString.class] || proof.length != 64) return NO;
    NSData *providedData = [proof dataUsingEncoding:NSASCIIStringEncoding];
    if (providedData.length != 64) return NO;
    const char *a = expected.UTF8String;
    const char *b = providedData.bytes;
    if (a == NULL || b == NULL) return NO;
    uint32_t difference = 0;
    for (NSUInteger i = 0; i < 64; i++) {
        char c = b[i];
        BOOL validHex = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
        difference |= (uint32_t)((uint8_t)a[i] ^ (uint8_t)c);
        difference |= validHex ? 0U : 1U;
    }
    return difference == 0;
}
@end
