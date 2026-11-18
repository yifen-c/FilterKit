#import "FKHelperKeyConfirmationTests.h"
#import "FKHelperKeyConfirmation.h"
#import <string.h>

@implementation FKHelperKeyConfirmationTests

+ (NSUInteger)checkCount { return 10; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperKeyConfirmation *confirmation = [FKHelperKeyConfirmation new];
    NSMutableData *key = [NSMutableData dataWithLength:32];
    memset(key.mutableBytes, 0x5a, key.length);
    NSString *digest = @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    NSString *clientProof = [confirmation proofForRole:FKHelperConfirmationRoleClient
                                              sessionID:@"s-1"
                                        transcriptDigest:digest
                                                     key:key];
    NSString *helperProof = [confirmation proofForRole:FKHelperConfirmationRoleHelper
                                              sessionID:@"s-1"
                                        transcriptDigest:digest
                                                     key:key];
    if (clientProof.length != 64) [failures addObject:@"KCF1501 客户端确认码生成失败"];
    if (helperProof.length != 64) [failures addObject:@"KCF1502 Helper 确认码生成失败"];
    if ([clientProof isEqualToString:helperProof]) [failures addObject:@"KCF1503 双向确认必须域分离"];
    if (![confirmation verifyProof:clientProof role:FKHelperConfirmationRoleClient sessionID:@"s-1" transcriptDigest:digest key:key]) {
        [failures addObject:@"KCF1504 正确客户端确认码应通过"];
    }
    if ([confirmation verifyProof:clientProof role:FKHelperConfirmationRoleHelper sessionID:@"s-1" transcriptDigest:digest key:key]) {
        [failures addObject:@"KCF1505 角色错配必须拒绝"];
    }
    if ([confirmation verifyProof:clientProof role:FKHelperConfirmationRoleClient sessionID:@"s-2" transcriptDigest:digest key:key]) {
        [failures addObject:@"KCF1506 会话错配必须拒绝"];
    }
    NSString *otherDigest = [@"f" stringByPaddingToLength:64 withString:@"f" startingAtIndex:0];
    if ([confirmation verifyProof:clientProof role:FKHelperConfirmationRoleClient sessionID:@"s-1" transcriptDigest:otherDigest key:key]) {
        [failures addObject:@"KCF1507 转录摘要错配必须拒绝"];
    }
    if ([confirmation proofForRole:FKHelperConfirmationRoleClient sessionID:@"s" transcriptDigest:digest key:[NSMutableData dataWithLength:16]]) {
        [failures addObject:@"KCF1508 短密钥必须拒绝"];
    }
    if ([confirmation proofForRole:FKHelperConfirmationRoleClient sessionID:@"s" transcriptDigest:@"bad" key:key]) {
        [failures addObject:@"KCF1509 非法摘要必须拒绝"];
    }
    if ([confirmation verifyProof:@"bad" role:FKHelperConfirmationRoleClient sessionID:@"s-1" transcriptDigest:digest key:key]) {
        [failures addObject:@"KCF1510 非法证明必须拒绝"];
    }
    return failures.copy;
}

@end
