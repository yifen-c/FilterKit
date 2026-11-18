#import "FKHelperAuthenticationTests.h"
#import "FKHelperMessageAuthenticator.h"

@implementation FKHelperAuthenticationTests
+ (NSUInteger)checkCount { return 9; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *failures = [NSMutableArray array];
    FKHelperMessageAuthenticator *auth = [FKHelperMessageAuthenticator new];
    NSData *data = [@"read-only request" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *key = [NSMutableData dataWithLength:32];
    for (NSUInteger i = 0; i < key.length; i++) ((uint8_t *)key.mutableBytes)[i] = (uint8_t)(i + 1);
    NSString *signature = [auth signatureForData:data sessionID:@"session-A" keyID:@"test-key" key:key];
    if (signature.length != 64) [failures addObject:@"AUT1301 HMAC-SHA256 应生成 64 位十六进制签名"];
    FKHelperMessageAuthenticationResult *valid = [auth verifyData:data sessionID:@"session-A" key:key keyID:@"test-key" signature:signature ?: @""];
    if (!valid.valid || ![valid.reasonCode isEqualToString:@"verified"]) [failures addObject:@"AUT1302 正确签名应验证通过"];
    if ([[auth signatureForData:data sessionID:@"session-B" keyID:@"test-key" key:key] isEqualToString:signature]) [failures addObject:@"AUT1303 签名必须绑定会话标识"];
    if ([[auth signatureForData:data sessionID:@"session-A" keyID:@"other-key" key:key] isEqualToString:signature]) [failures addObject:@"AUT1309 签名必须绑定密钥标识"];
    FKHelperMessageAuthenticationResult *wrongSession = [auth verifyData:data sessionID:@"session-B" key:key keyID:@"test-key" signature:signature ?: @""];
    if (wrongSession.valid) [failures addObject:@"AUT1304 跨会话签名不得通过"];
    NSMutableString *tampered = [signature mutableCopy] ?: [NSMutableString string];
    if (tampered.length) [tampered replaceCharactersInRange:NSMakeRange(0, 1) withString:( [tampered characterAtIndex:0] == '0' ? @"1" : @"0")];
    if ([auth verifyData:data sessionID:@"session-A" key:key keyID:@"test-key" signature:tampered].valid) [failures addObject:@"AUT1305 篡改签名不得通过"];
    if ([auth signatureForData:data sessionID:@"session-A" keyID:@"test-key" key:[NSMutableData dataWithLength:31]] != nil) [failures addObject:@"AUT1306 小于 256 bit 的密钥必须拒绝"];
    if ([auth signatureForData:[NSData data] sessionID:@"session-A" keyID:@"test-key" key:key] != nil) [failures addObject:@"AUT1307 空报文必须拒绝"];
    FKHelperMessageAuthenticationResult *badFormat = [auth verifyData:data sessionID:@"session-A" key:key keyID:@"test-key" signature:@"not-a-signature"];
    if (badFormat.valid || ![badFormat.reasonCode isEqualToString:@"invalid_authentication_input"]) [failures addObject:@"AUT1308 非法签名格式必须拒绝"];
    return failures.copy;
}
@end
