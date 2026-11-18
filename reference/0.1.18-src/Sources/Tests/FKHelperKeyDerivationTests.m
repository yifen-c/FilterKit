#import "FKHelperKeyDerivationTests.h"
#import "FKHelperKeyDerivation.h"
#import <string.h>

@implementation FKHelperKeyDerivationTests

+ (NSUInteger)checkCount {
    return 9;
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperKeyDerivation *derivation = [FKHelperKeyDerivation new];
    NSMutableData *inputKey = [NSMutableData dataWithLength:32];
    memset(inputKey.mutableBytes, 0x0b, inputKey.length);
    NSData *salt = [@"salt-value-0123456789" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *info = [@"FilterKit test" dataUsingEncoding:NSUTF8StringEncoding];

    NSData *first = [derivation deriveKeyFromInputKey:inputKey salt:salt info:info outputLength:32];
    if (first.length != 32) {
        [failures addObject:@"KDF1401 HKDF 应生成 32 字节密钥"];
    }

    NSData *repeat = [derivation deriveKeyFromInputKey:inputKey salt:salt info:info outputLength:32];
    if (![first isEqualToData:repeat]) {
        [failures addObject:@"KDF1402 相同输入应得到相同派生结果"];
    }

    NSData *vector = [derivation deriveKeyFromInputKey:inputKey salt:salt info:info outputLength:42];
    const char *expected = "149dd20d29d75124029f26ad4bd5728c136aa0a639cc7ebd27251fc59c66bf0d493682d537c5471fa8c2";
    NSMutableString *actual = [NSMutableString string];
    const uint8_t *vectorBytes = vector.bytes;
    for (NSUInteger index = 0; index < vector.length; index++) {
        [actual appendFormat:@"%02x", vectorBytes[index]];
    }
    if (![actual isEqualToString:[NSString stringWithUTF8String:expected]]) {
        [failures addObject:@"KDF1409 HKDF-SHA256 标准测试向量不匹配"];
    }

    NSData *otherSalt = [@"other-salt" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *changed = [derivation deriveKeyFromInputKey:inputKey salt:otherSalt info:info outputLength:32];
    if ([changed isEqualToData:first]) {
        [failures addObject:@"KDF1403 Salt 必须影响派生结果"];
    }

    NSData *shortKey = [NSMutableData dataWithLength:31];
    if ([derivation deriveKeyFromInputKey:shortKey salt:salt info:info outputLength:32]) {
        [failures addObject:@"KDF1404 短输入密钥必须拒绝"];
    }

    if ([derivation deriveKeyFromInputKey:inputKey salt:salt info:info outputLength:8161]) {
        [failures addObject:@"KDF1405 超出 RFC 5869 上限必须拒绝"];
    }

    NSString *clientNonce = @"client-nonce-012345678901234567890";
    NSString *helperNonce = @"helper-nonce-012345678901234567890";
    NSData *sessionKey = [derivation deriveSessionKeyFromInputKey:inputKey
                                                       clientNonce:clientNonce
                                                       helperNonce:helperNonce
                                                            peerID:@"com.filterkit.helper"
                                                     protocolMajor:1
                                                     protocolMinor:0];
    if (sessionKey.length != 32) {
        [failures addObject:@"KDF1406 会话密钥应派生成功"];
    }

    NSData *otherPeerKey = [derivation deriveSessionKeyFromInputKey:inputKey
                                                         clientNonce:clientNonce
                                                         helperNonce:helperNonce
                                                              peerID:@"other.helper"
                                                       protocolMajor:1
                                                       protocolMinor:0];
    if ([otherPeerKey isEqualToData:sessionKey]) {
        [failures addObject:@"KDF1407 Peer 身份必须绑定派生结果"];
    }

    NSData *otherNonceKey = [derivation deriveSessionKeyFromInputKey:inputKey
                                                          clientNonce:@"different-client-nonce-0123456789012345"
                                                          helperNonce:helperNonce
                                                               peerID:@"com.filterkit.helper"
                                                        protocolMajor:1
                                                        protocolMinor:0];
    if ([otherNonceKey isEqualToData:sessionKey]) {
        [failures addObject:@"KDF1408 双方随机数必须绑定派生结果"];
    }

    return failures.copy;
}

@end
