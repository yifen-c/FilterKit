#import "FKHelperTransportAssessmentTests.h"
#import "FKHelperTransportAssessment.h"

@implementation FKHelperTransportAssessmentTests
+ (NSUInteger)checkCount { return 8; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *failures = [NSMutableArray array];
    FKHelperTransportAssessmentEngine *engine = [FKHelperTransportAssessmentEngine new];
    NSArray<FKHelperTransportAssessment *> *empty = [engine assessCandidatesWithEvidence:@{}];
    if (empty.count != 2 || empty[0].eligible || empty[1].eligible) [failures addObject:@"TAS1301 缺少证据时两个候选均不可用"];
    if ([engine selectedTransportWithEvidence:@{}] != FKHelperTransportKindUndecided) [failures addObject:@"TAS1302 无证据时不得选择传输"];
    NSDictionary *mach = @{@"machServiceObserved": @YES, @"peerAuditVerified": @YES, @"lifecycleVerified": @YES, @"platformSupportVerified": @YES};
    NSArray *machResult = [engine assessCandidatesWithEvidence:mach];
    if (!((FKHelperTransportAssessment *)machResult[0]).eligible) [failures addObject:@"TAS1303 完整 Mach 证据应通过候选评估"];
    if ([engine selectedTransportWithEvidence:mach] != FKHelperTransportKindMachService) [failures addObject:@"TAS1304 唯一完整候选应给出建议类型"];
    NSDictionary *socket = @{@"socketEndpointObserved": @YES, @"socketPermissionVerified": @YES, @"peerCredentialVerified": @YES, @"lifecycleVerified": @YES};
    if ([engine selectedTransportWithEvidence:socket] != FKHelperTransportKindUnixSocket) [failures addObject:@"TAS1305 Unix Socket 完整证据应给出建议类型"];
    NSMutableDictionary *invalid = [mach mutableCopy]; invalid[@"peerAuditVerified"] = @"YES";
    if (((FKHelperTransportAssessment *)[engine assessCandidatesWithEvidence:invalid][0]).eligible) [failures addObject:@"TAS1306 字符串 YES 不得冒充布尔证据"];
    NSMutableDictionary *both = [mach mutableCopy]; [both addEntriesFromDictionary:socket];
    if ([engine selectedTransportWithEvidence:both] != FKHelperTransportKindUndecided) [failures addObject:@"TAS1307 两个候选均通过时保持未决"];
    if (![[empty[0] JSONDictionary][@"missingEvidence"] isKindOfClass:NSArray.class]) [failures addObject:@"TAS1308 评估报告应输出缺失证据"];
    return failures.copy;
}
@end
