#import "FKSecurityAuditManager.h"

@implementation FKSecurityAuditManager

- (instancetype)init {
    if ((self = [super init])) {
        _store = [FKSecurityEvidenceStore new];
    }
    return self;
}

- (void)recordEventType:(FKSecurityEventType)type
                 target:(NSString *)target
                 result:(NSString *)result
                 reason:(NSString *)reason
               evidence:(NSDictionary *)evidence {
    FKSecurityEvent *event = [FKSecurityEvent eventWithType:type
                                                     target:target
                                                     result:result
                                                     reason:reason
                                                   evidence:evidence];
    [self.store appendEvent:event];
}

- (FKSecurityReport *)securityReport {
    FKSecurityReport *report = [FKSecurityReport reportWithEvents:self.store.events];
    report.scanID = self.scanID;
    report.environment = self.environment;
    report.injector = self.injector;
    report.helperTrust = self.helperTrust;
    report.securityGate = self.securityGate;
    report.testSummary = self.testSummary;
    return report;
}

- (NSDictionary *)JSONDictionary {
    return [self.securityReport JSONDictionary];
}

@end
