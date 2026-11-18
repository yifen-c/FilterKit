#import "FKHelperKeyDerivation.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import <stdint.h>
#import <string.h>
#import <CoreFoundation/CoreFoundation.h>

@implementation FKHelperKeyDerivation
- (NSData *)deriveKeyFromInputKey:(NSData *)inputKey salt:(NSData *)salt info:(NSData *)info outputLength:(NSUInteger)outputLength {
    if (![inputKey isKindOfClass:NSData.class] || inputKey.length < 32 ||
        ![salt isKindOfClass:NSData.class] || salt.length == 0 || salt.length > 1024 ||
        ![info isKindOfClass:NSData.class] || info.length == 0 || info.length > 1024 ||
        outputLength == 0 || outputLength > 255 * CC_SHA256_DIGEST_LENGTH) return nil;

    // RFC 5869 Extract。
    uint8_t prk[CC_SHA256_DIGEST_LENGTH] = {0};
    CCHmac(kCCHmacAlgSHA256, salt.bytes, salt.length, inputKey.bytes, inputKey.length, prk);

    // RFC 5869 Expand。
    NSMutableData *output = [NSMutableData dataWithCapacity:outputLength];
    NSMutableData *previous = [NSMutableData data];
    uint8_t counter = 1;
    while (output.length < outputLength) {
        NSMutableData *blockInput = [NSMutableData dataWithData:previous];
        [blockInput appendData:info];
        [blockInput appendBytes:&counter length:1];
        uint8_t block[CC_SHA256_DIGEST_LENGTH] = {0};
        CCHmac(kCCHmacAlgSHA256, prk, sizeof(prk), blockInput.bytes, blockInput.length, block);
        if (blockInput.length) memset(blockInput.mutableBytes, 0, blockInput.length);
        [previous setData:[NSData dataWithBytes:block length:sizeof(block)]];
        NSUInteger remaining = outputLength - output.length;
        [output appendBytes:block length:MIN(remaining, sizeof(block))];
        memset(block, 0, sizeof(block));
        counter++;
    }
    memset(prk, 0, sizeof(prk));
    if (previous.length) memset(previous.mutableBytes, 0, previous.length);
    return output.copy;
}

- (NSData *)deriveSessionKeyFromInputKey:(NSData *)inputKey clientNonce:(NSString *)clientNonce helperNonce:(NSString *)helperNonce peerID:(NSString *)peerID protocolMajor:(NSInteger)major protocolMinor:(NSInteger)minor {
    if (![clientNonce isKindOfClass:NSString.class] || clientNonce.length < 32 || clientNonce.length > 128 ||
        ![helperNonce isKindOfClass:NSString.class] || helperNonce.length < 32 || helperNonce.length > 128 ||
        ![peerID isKindOfClass:NSString.class] || peerID.length == 0 || peerID.length > 255 ||
        major < 1 || major > UINT16_MAX || minor < 0 || minor > UINT16_MAX) return nil;
    NSData *client = [clientNonce dataUsingEncoding:NSUTF8StringEncoding];
    NSData *helper = [helperNonce dataUsingEncoding:NSUTF8StringEncoding];
    NSData *peer = [peerID dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *salt = [NSMutableData data];
    uint16_t clientLength = CFSwapInt16HostToBig((uint16_t)client.length);
    uint16_t helperLength = CFSwapInt16HostToBig((uint16_t)helper.length);
    uint16_t peerLength = CFSwapInt16HostToBig((uint16_t)peer.length);
    [salt appendBytes:&clientLength length:2]; [salt appendData:client];
    [salt appendBytes:&helperLength length:2]; [salt appendData:helper];
    [salt appendBytes:&peerLength length:2]; [salt appendData:peer];
    uint16_t majorValue = CFSwapInt16HostToBig((uint16_t)major);
    uint16_t minorValue = CFSwapInt16HostToBig((uint16_t)minor);
    [salt appendBytes:&majorValue length:2]; [salt appendBytes:&minorValue length:2];
    NSData *info = [@"FilterKit.Helper.SessionKey.v1" dataUsingEncoding:NSUTF8StringEncoding];
    return [self deriveKeyFromInputKey:inputKey salt:salt info:info outputLength:32];
}
@end
