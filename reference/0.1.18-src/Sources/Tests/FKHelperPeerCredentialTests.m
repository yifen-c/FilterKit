#import "FKHelperPeerCredentialTests.h"
#import "FKHelperPeerCredentialEvidence.h"
@implementation FKHelperPeerCredentialTests
+ (NSUInteger)checkCount { return 8; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *f = [NSMutableArray array]; NSDate *now = [NSDate date];
    FKHelperPeerCredentialVerifier *v = [FKHelperPeerCredentialVerifier new];
    FKHelperPeerCredentialVerificationResult *none = [v verifyEvidence:nil atDate:now];
    if (none.verified || none.status != FKHelperPeerCredentialStatusUnavailable) [f addObject:@"PCR1701 缺少凭据必须 Unavailable"];
    FKHelperPeerCredentialEvidence *unsupported = [FKHelperPeerCredentialEvidence unsupportedEvidence];
    if (unsupported.source != FKHelperPeerCredentialSourceUnsupported) [f addObject:@"PCR1702 默认凭据来源必须 Unsupported"];
    FKHelperPeerCredentialVerificationResult *u = [v verifyEvidence:unsupported atDate:now];
    if (u.verified) [f addObject:@"PCR1703 Unsupported 凭据不得通过"];
    FKHelperPeerCredentialEvidence *mock = [FKHelperPeerCredentialEvidence mockEvidenceWithProcessID:100 digest:[@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0] date:now];
    if ([v verifyEvidence:mock atDate:now].verified) [f addObject:@"PCR1704 Mock 凭据不得 Verified"];
    FKHelperPeerCredentialEvidence *selfReported = [FKHelperPeerCredentialEvidence selfReportedEvidenceWithProcessID:100 digest:@"claimed" date:now];
    if ([v verifyEvidence:selfReported atDate:now].verified) [f addObject:@"PCR1705 自报身份不得 Verified"];
    if (![mock.JSONDictionary[@"source"] isEqualToString:@"mock"]) [f addObject:@"PCR1706 Mock 来源应正确标记"];
    if ([v verifyEvidence:mock atDate:nil].verified) [f addObject:@"PCR1707 非法评估时间不得通过"];
    if ([mock.collectorIdentifier isEqualToString:@"system"]) [f addObject:@"PCR1708 Mock 不得伪装系统采集器"];
    return f.copy;
}
@end
