#import "FKOperationEligibility.h"

static NSString *FKEligibilityDecisionCode(FKOperationDecision decision) {
    switch (decision) {
        case FKOperationDecisionAllowed: return @"allowed";
        case FKOperationDecisionDenied: return @"denied";
        case FKOperationDecisionNeedsConfirmation: return @"needs_confirmation";
        case FKOperationDecisionUnsupported: return @"unsupported";
        case FKOperationDecisionUnknown:
        default: return @"unknown";
    }
}

@implementation FKOperationEligibility

- (NSDictionary *)JSONDictionary {
    NSMutableArray *checkJSON = [NSMutableArray array];
    for (FKOperationCheck *check in self.checks) [checkJSON addObject:check.JSONDictionary];
    return @{
        @"mode": self.mode ?: @"preview_only",
        @"eligible": @(self.eligible),
        @"status": self.status ?: @"preview",
        @"decision": FKEligibilityDecisionCode(self.decision),
        @"reason_codes": self.reasonCodes ?: @[],
        @"app_bundle_id": self.appBundleID ?: @"",
        @"checks": checkJSON.copy,
        @"block_reasons": self.blockReasons ?: @[],
        @"policy": self.policy ? [self.policy JSONDictionary] : @{}
    };
}

@end
