#import "FKHelperHandshakeTranscriptTests.h"
#import "FKHelperHandshakeTranscript.h"

@implementation FKHelperHandshakeTranscriptTests

+ (NSUInteger)checkCount {
    return 9;
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperHandshakeTranscript *transcript = [FKHelperHandshakeTranscript new];
    NSDictionary *base = @{
        @"sessionID": @"session-01",
        @"clientID": @"com.filterkit.manager",
        @"helperID": @"com.filterkit.helper",
        @"clientNonce": @"client-nonce-012345678901234567890",
        @"helperNonce": @"helper-nonce-012345678901234567890",
        @"clientBuildID": @"APP-115",
        @"helperBuildID": @"FKH-0118",
        @"protocolMajor": @1,
        @"protocolMinor": @0,
        @"capabilities": @[@"plugin.list", @"helper.info"]
    };

    NSString *digest = [transcript digestForFields:base];
    if (digest.length != 64) {
        [failures addObject:@"TRN1401 完整转录应生成 SHA-256 摘要"];
    }
    if (![transcript verifyFields:base expectedDigest:digest]) {
        [failures addObject:@"TRN1402 原始转录应验证通过"];
    }

    NSMutableDictionary *changed = [base mutableCopy];
    changed[@"helperNonce"] = @"different-helper-nonce-0123456789";
    if ([transcript verifyFields:changed expectedDigest:digest]) {
        [failures addObject:@"TRN1403 随机数变化必须导致验证失败"];
    }

    changed = [base mutableCopy];
    changed[@"capabilities"] = @[@"plugin.enable"];
    if ([transcript digestForFields:changed]) {
        [failures addObject:@"TRN1404 写能力不得进入握手转录"];
    }

    changed = [base mutableCopy];
    changed[@"capabilities"] = @[@"plugin.list", @"plugin.list"];
    if ([transcript digestForFields:changed]) {
        [failures addObject:@"TRN1405 重复能力必须拒绝"];
    }

    changed = [base mutableCopy];
    changed[@"protocolMajor"] = @YES;
    if ([transcript digestForFields:changed]) {
        [failures addObject:@"TRN1406 布尔协议版本必须拒绝"];
    }

    if ([transcript verifyFields:base expectedDigest:@"bad-digest"]) {
        [failures addObject:@"TRN1407 错误摘要格式必须拒绝"];
    }

    changed = [base mutableCopy];
    changed[@"capabilities"] = @[@"helper.info", @"plugin.list"];
    if (![[transcript digestForFields:changed] isEqualToString:digest]) {
        [failures addObject:@"TRN1408 能力顺序不应改变规范转录摘要"];
    }

    changed = [base mutableCopy];
    changed[@"unrecognized"] = @1;
    if ([transcript digestForFields:changed]) {
        [failures addObject:@"TRN1409 未知转录字段必须拒绝"];
    }

    return failures.copy;
}

@end
