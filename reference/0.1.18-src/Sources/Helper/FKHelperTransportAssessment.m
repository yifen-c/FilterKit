#import "FKHelperTransportAssessment.h"
#import <CoreFoundation/CoreFoundation.h>

@interface FKHelperTransportAssessment ()
@property (nonatomic, copy, readwrite) NSString *candidate;
@property (nonatomic, copy, readwrite) NSString *status;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *missingEvidence;
@property (nonatomic, assign, readwrite) BOOL eligible;
@end

@implementation FKHelperTransportAssessment
- (NSDictionary *)JSONDictionary {
    return @{@"candidate": self.candidate ?: @"", @"status": self.status ?: @"unknown",
             @"eligible": @(self.eligible), @"missingEvidence": self.missingEvidence ?: @[]};
}
@end

@implementation FKHelperTransportAssessmentEngine
- (NSArray<FKHelperTransportAssessment *> *)assessCandidatesWithEvidence:(NSDictionary *)evidence {
    NSDictionary *safe = [evidence isKindOfClass:NSDictionary.class] ? evidence : @{};
    NSArray<NSDictionary *> *definitions = @[
        @{@"name": @"mach_service", @"keys": @[@"machServiceObserved", @"peerAuditVerified", @"lifecycleVerified", @"platformSupportVerified"]},
        @{@"name": @"unix_domain_socket", @"keys": @[@"socketEndpointObserved", @"socketPermissionVerified", @"peerCredentialVerified", @"lifecycleVerified"]}
    ];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:definitions.count];
    for (NSDictionary *definition in definitions) {
        NSMutableArray *missing = [NSMutableArray array];
        for (NSString *key in definition[@"keys"]) {
            id value = safe[key];
            if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID() || ![value boolValue]) [missing addObject:key];
        }
        FKHelperTransportAssessment *item = [FKHelperTransportAssessment new];
        item.candidate = definition[@"name"];
        item.eligible = (missing.count == 0);
        item.status = item.eligible ? @"evidence_complete_pending_device_review" : @"unverified";
        item.missingEvidence = missing.copy;
        [results addObject:item];
    }
    return results.copy;
}
- (FKHelperTransportKind)selectedTransportWithEvidence:(NSDictionary *)evidence {
    NSArray<FKHelperTransportAssessment *> *items = [self assessCandidatesWithEvidence:evidence];
    BOOL mach = items.count > 0 && items[0].eligible;
    BOOL socket = items.count > 1 && items[1].eligible;
    if (mach == socket) return FKHelperTransportKindUndecided;
    // 这里只返回候选建议；不创建端点、不建立连接，也不改变部署状态。
    return mach ? FKHelperTransportKindMachService : FKHelperTransportKindUnixSocket;
}
@end
