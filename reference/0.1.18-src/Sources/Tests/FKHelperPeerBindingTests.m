#import "FKHelperPeerBindingTests.h"
#import "FKHelperPeerBinding.h"

@implementation FKHelperPeerBindingTests

+ (NSUInteger)checkCount { return 10; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSString *digest = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    FKHelperPeerBinding *binding = [[FKHelperPeerBinding alloc] initWithSessionID:@"s1"
                                                                          clientID:@"com.filterkit.manager"
                                                                          helperID:@"com.filterkit.helper"
                                                                      helperBuildID:@"FKH-0118"
                                                                   credentialDigest:digest
                                                                   transcriptDigest:digest];
    if (!binding) [failures addObject:@"PBD1701 合法 Peer 绑定创建失败"];
    if (![binding matchesExpectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-0118" expectedCredential:digest]) {
        [failures addObject:@"PBD1702 正确身份绑定应匹配"];
    }
    if ([binding matchesExpectedHelperID:@"com.other.helper" expectedBuildID:@"FKH-0118" expectedCredential:digest]) {
        [failures addObject:@"PBD1703 Helper ID 错配必须拒绝"];
    }
    if ([binding matchesExpectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-OLD" expectedCredential:digest]) {
        [failures addObject:@"PBD1704 Build ID 错配必须拒绝"];
    }
    NSString *otherDigest = [@"b" stringByPaddingToLength:64 withString:@"b" startingAtIndex:0];
    if ([binding matchesExpectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-0118" expectedCredential:otherDigest]) {
        [failures addObject:@"PBD1705 Peer 凭据摘要错配必须拒绝"];
    }
    NSDictionary *json = [binding JSONDictionary];
    if (![json[@"sessionID"] isEqualToString:@"s1"]) [failures addObject:@"PBD1706 JSON 会话标识丢失"];
    if ([[FKHelperPeerBinding alloc] initWithSessionID:@"" clientID:@"c" helperID:@"h" helperBuildID:@"b" credentialDigest:digest transcriptDigest:digest]) {
        [failures addObject:@"PBD1707 空会话标识必须拒绝"];
    }
    if ([[FKHelperPeerBinding alloc] initWithSessionID:@"s" clientID:@"" helperID:@"h" helperBuildID:@"b" credentialDigest:digest transcriptDigest:digest]) {
        [failures addObject:@"PBD1708 空客户端标识必须拒绝"];
    }
    if ([[FKHelperPeerBinding alloc] initWithSessionID:@"s" clientID:@"c" helperID:@"h" helperBuildID:@"b" credentialDigest:@"bad" transcriptDigest:digest]) {
        [failures addObject:@"PBD1709 非法凭据摘要必须拒绝"];
    }
    if ([[FKHelperPeerBinding alloc] initWithSessionID:@"s" clientID:@"c" helperID:@"h" helperBuildID:@"b" credentialDigest:digest transcriptDigest:@"bad"]) {
        [failures addObject:@"PBD1710 非法转录摘要必须拒绝"];
    }
    return failures.copy;
}

@end
