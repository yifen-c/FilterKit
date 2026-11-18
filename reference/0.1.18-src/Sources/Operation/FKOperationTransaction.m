#import "FKOperationTransaction.h"

static NSString *FKTransactionDecisionCode(FKOperationDecision decision) {
    switch (decision) {
        case FKOperationDecisionAllowed: return @"allowed";
        case FKOperationDecisionDenied: return @"denied";
        case FKOperationDecisionNeedsConfirmation: return @"needs_confirmation";
        case FKOperationDecisionUnsupported: return @"unsupported";
        case FKOperationDecisionUnknown:
        default: return @"unknown";
    }
}

@implementation FKOperationTransaction

+ (instancetype)transactionWithRequest:(FKOperationRequest *)request {
    FKOperationTransaction *transaction = [self new];
    transaction.request = request;
    transaction.operationID = request.requestID ?: [NSUUID UUID].UUIDString;
    transaction.stateMachine = [FKOperationStateMachine new];
    transaction.decision = FKOperationDecisionUnknown;
    transaction.checks = @[];
    transaction.reasons = @[];
    transaction.createdAt = [NSDate date];
    transaction.updatedAt = [NSDate date];
    return transaction;
}

- (BOOL)advanceTo:(FKOperationTransactionState)state error:(NSError *_Nullable *_Nullable)error {
    BOOL ok = [self.stateMachine transitionTo:state error:error];
    if (ok) self.updatedAt = [NSDate date];
    return ok;
}

- (NSDictionary *)JSONDictionary {
    NSMutableArray<NSDictionary *> *checkJSON = [NSMutableArray array];
    for (FKOperationCheck *check in self.checks) [checkJSON addObject:check.JSONDictionary];
    NSDate *timestamp = self.updatedAt ?: self.createdAt;
    return @{
        @"operation_id": self.operationID ?: @"",
        @"request": self.request ? [self.request JSONDictionary] : @{},
        @"state": [FKOperationStateMachine stateCode:self.stateMachine.state],
        @"state_text": [FKOperationStateMachine stateText:self.stateMachine.state],
        @"decision": FKTransactionDecisionCode(self.decision),
        @"checks": checkJSON.copy,
        @"reasons": self.reasons ?: @[],
        @"before_state": self.beforeState ?: @"",
        @"target_state": self.targetState ?: @"",
        @"after_state": self.afterState ?: @"",
        @"before_hash": self.beforeHash ?: @"",
        @"after_hash": self.afterHash ?: @"",
        @"backup_id": self.backupID ?: @"",
        @"verification_result": self.verificationResult ?: @"none",
        @"rollback_result": self.rollbackResult ?: @"none",
        @"failure_reason": self.failureReason ?: @"",
        @"helper_identity": self.helperIdentity ?: @"",
        @"helper_version": self.helperVersion ?: @"",
        @"protocol_version": self.protocolVersion ?: @"",
        @"updated_at": timestamp ? [[NSISO8601DateFormatter new] stringFromDate:timestamp] : @""
    };
}

@end
