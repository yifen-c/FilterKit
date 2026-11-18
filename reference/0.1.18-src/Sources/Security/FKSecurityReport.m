#import "FKSecurityReport.h"

/// 安全报告结构版本；调整字段结构时递增。
static const NSUInteger FKSecurityReportSchemaVersion = 1;

@implementation FKSecurityReport

+ (instancetype)reportWithEvents:(NSArray<FKSecurityEvent *> *)events {
    FKSecurityReport *report = [self new];
    report.events = events ?: @[];
    report.generatedAt = [NSDate date];
    return report;
}

- (NSDictionary *)JSONDictionary {
    NSMutableArray *eventJSON = [NSMutableArray array];
    NSMutableDictionary *byType = [NSMutableDictionary dictionary];
    NSMutableDictionary *byResult = [NSMutableDictionary dictionary];
    NSUInteger passed = 0, failed = 0, unknown = 0, blocked = 0;

    for (FKSecurityEvent *event in self.events) {
        [eventJSON addObject:event.JSONDictionary];
        byType[event.eventType] = @([byType[event.eventType] unsignedIntegerValue] + 1);
        byResult[event.result] = @([byResult[event.result] unsignedIntegerValue] + 1);
        NSString *result = event.result ?: @"";
        if ([result isEqualToString:@"passed"] || [result isEqualToString:@"verified"]) passed++;
        else if ([result isEqualToString:@"failed"]) failed++;
        else if ([result isEqualToString:@"rejected"]) blocked++;
        else unknown++;
    }

    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    return @{
        @"schema_version": @(FKSecurityReportSchemaVersion),
        @"scan_id": self.scanID ?: @"",
        @"generated_at": [formatter stringFromDate:self.generatedAt ?: [NSDate date]],
        @"environment": self.environment ?: @{},
        @"injector": self.injector ?: @{},
        @"helper_trust": self.helperTrust ?: @{},
        @"security_gate": self.securityGate ?: @{},
        @"events": eventJSON.copy,
        @"test_summary": self.testSummary ?: @{@"executed": @NO, @"status": @"NotTested"},
        @"summary": @{
            @"passed": @(passed),
            @"failed": @(failed),
            @"unknown": @(unknown),
            @"blocked": @(blocked),
            @"total": @(self.events.count)
        },
        @"by_type": byType.copy,
        @"by_result": byResult.copy
    };
}

@end
