#import "FKHelperHandshakeTranscript.h"
#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>
#import <string.h>
#import <stdint.h>

@implementation FKHelperHandshakeTranscript

- (NSData *)canonicalDataWithFields:(NSDictionary *)fields {
    if (![fields isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    NSSet<NSString *> *allowedFields = [NSSet setWithArray:@[
        @"sessionID", @"clientID", @"helperID", @"clientNonce", @"helperNonce",
        @"clientBuildID", @"helperBuildID", @"protocolMajor", @"protocolMinor", @"capabilities"
    ]];
    for (id key in fields) {
        if (![key isKindOfClass:NSString.class] || ![allowedFields containsObject:key]) {
            return nil;
        }
    }

    NSArray<NSString *> *requiredFields = @[
        @"sessionID", @"clientID", @"helperID", @"clientNonce", @"helperNonce",
        @"clientBuildID", @"helperBuildID"
    ];
    NSMutableDictionary *canonical = [NSMutableDictionary dictionary];
    for (NSString *key in requiredFields) {
        id value = fields[key];
        if (![value isKindOfClass:NSString.class] || [value length] == 0 || [value length] > 256) {
            return nil;
        }
        BOOL isNonce = [key isEqualToString:@"clientNonce"] || [key isEqualToString:@"helperNonce"];
        if (isNonce && [value length] < 32) {
            return nil;
        }
        canonical[key] = value;
    }

    id majorValue = fields[@"protocolMajor"];
    id minorValue = fields[@"protocolMinor"];
    BOOL majorIsBoolean = [majorValue isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)majorValue) == CFBooleanGetTypeID();
    BOOL minorIsBoolean = [minorValue isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)minorValue) == CFBooleanGetTypeID();
    if (![majorValue isKindOfClass:NSNumber.class] || majorIsBoolean ||
        ![minorValue isKindOfClass:NSNumber.class] || minorIsBoolean) {
        return nil;
    }

    NSInteger major = [majorValue integerValue];
    NSInteger minor = [minorValue integerValue];
    if (major < 1 || major > 65535 || minor < 0 || minor > 65535 ||
        [majorValue doubleValue] != (double)major || [minorValue doubleValue] != (double)minor) {
        return nil;
    }
    canonical[@"protocolMajor"] = @(major);
    canonical[@"protocolMinor"] = @(minor);

    NSArray *capabilities = fields[@"capabilities"];
    if (![capabilities isKindOfClass:NSArray.class] || capabilities.count > 32) {
        return nil;
    }
    NSSet<NSString *> *readOnlyAllowlist = [NSSet setWithArray:@[
        @"helper.info", @"helper.health", @"plugin.list", @"plugin.inspect", @"config.inspect"
    ]];
    NSMutableSet<NSString *> *seenCapabilities = [NSMutableSet set];
    for (id capability in capabilities) {
        if (![capability isKindOfClass:NSString.class] ||
            ![readOnlyAllowlist containsObject:capability] ||
            [seenCapabilities containsObject:capability]) {
            return nil;
        }
        [seenCapabilities addObject:capability];
    }
    canonical[@"capabilities"] = [[seenCapabilities allObjects] sortedArrayUsingSelector:@selector(compare:)];

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:canonical
                                                   options:NSJSONWritingSortedKeys
                                                     error:&error];
    return error ? nil : data;
}

- (NSString *)digestForFields:(NSDictionary *)fields {
    NSData *data = [self canonicalDataWithFields:fields];
    if (!data || data.length == 0 || data.length > UINT32_MAX) {
        return nil;
    }

    uint8_t digest[CC_SHA256_DIGEST_LENGTH] = {0};
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:sizeof(digest) * 2];
    for (NSUInteger index = 0; index < sizeof(digest); index++) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    memset(digest, 0, sizeof(digest));
    return hex.copy;
}

- (BOOL)verifyFields:(NSDictionary *)fields expectedDigest:(NSString *)expectedDigest {
    NSString *actual = [self digestForFields:fields];
    if (actual.length != 64 || ![expectedDigest isKindOfClass:NSString.class] || expectedDigest.length != 64) {
        return NO;
    }

    const char *actualBytes = actual.UTF8String;
    const char *expectedBytes = expectedDigest.UTF8String;
    uint32_t mismatch = 0;
    for (NSUInteger index = 0; index < 64; index++) {
        unsigned char value = (unsigned char)expectedBytes[index];
        BOOL isHex = (value >= '0' && value <= '9') || (value >= 'a' && value <= 'f');
        mismatch |= (uint32_t)((unsigned char)actualBytes[index] ^ value);
        mismatch |= (uint32_t)(isHex ? 0 : 1);
    }
    return mismatch == 0;
}

@end
