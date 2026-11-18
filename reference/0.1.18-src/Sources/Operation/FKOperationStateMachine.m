#import "FKOperationStateMachine.h"

NSErrorDomain const FKOperationStateMachineErrorDomain = @"FilterKitOperationStateMachineError";

/// 合法流转表：key 为当前状态，value 为允许进入的下一状态集合。
static NSDictionary<NSNumber *, NSArray *> *FKTransitionTable(void) {
    static NSDictionary<NSNumber *, NSArray *> *table;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = @{
            @(FKOperationTransactionStateCreated): @[@(FKOperationTransactionStatePreflight)],
            @(FKOperationTransactionStatePreflight): @[@(FKOperationTransactionStateGateChecking),
                                                        @(FKOperationTransactionStateFailed)],
            @(FKOperationTransactionStateGateChecking): @[@(FKOperationTransactionStateBackup),
                                                           @(FKOperationTransactionStateFailed)],
            @(FKOperationTransactionStateBackup): @[@(FKOperationTransactionStateAwaitingConfirmation),
                                                     @(FKOperationTransactionStateFailed)],
            @(FKOperationTransactionStateAwaitingConfirmation): @[@(FKOperationTransactionStateApplying),
                                                                   @(FKOperationTransactionStateFailed)],
            @(FKOperationTransactionStateApplying): @[@(FKOperationTransactionStateVerifying),
                                                       @(FKOperationTransactionStateFailed)],
            @(FKOperationTransactionStateVerifying): @[@(FKOperationTransactionStateCompleted),
                                                       @(FKOperationTransactionStateFailed)],
            @(FKOperationTransactionStateFailed): @[@(FKOperationTransactionStateRollback),
                                                     @(FKOperationTransactionStateRecoveryRequired)],
            @(FKOperationTransactionStateRollback): @[@(FKOperationTransactionStateRolledBack),
                                                       @(FKOperationTransactionStateRecoveryRequired)],
            @(FKOperationTransactionStateCompleted): @[],
            @(FKOperationTransactionStateRolledBack): @[],
            @(FKOperationTransactionStateRecoveryRequired): @[]
        };
    });
    return table;
}

@implementation FKOperationStateMachine

- (instancetype)init {
    if ((self = [super init])) {
        _state = FKOperationTransactionStateCreated;
    }
    return self;
}

+ (BOOL)isTerminalState:(FKOperationTransactionState)state {
    switch (state) {
        case FKOperationTransactionStateCompleted:
        case FKOperationTransactionStateRolledBack:
        case FKOperationTransactionStateRecoveryRequired:
            return YES;
        default:
            return NO;
    }
}

+ (BOOL)canTransitionFrom:(FKOperationTransactionState)from to:(FKOperationTransactionState)to {
    NSArray *allowed = FKTransitionTable()[@(from)];
    return [allowed containsObject:@(to)];
}

+ (NSString *)stateText:(FKOperationTransactionState)state {
    switch (state) {
        case FKOperationTransactionStateCreated: return @"已创建";
        case FKOperationTransactionStatePreflight: return @"前置检查";
        case FKOperationTransactionStateGateChecking: return @"门禁校验";
        case FKOperationTransactionStateBackup: return @"备份配置";
        case FKOperationTransactionStateAwaitingConfirmation: return @"等待确认";
        case FKOperationTransactionStateApplying: return @"正在应用";
        case FKOperationTransactionStateVerifying: return @"正在验证";
        case FKOperationTransactionStateCompleted: return @"已完成";
        case FKOperationTransactionStateFailed: return @"操作失败";
        case FKOperationTransactionStateRollback: return @"正在回滚";
        case FKOperationTransactionStateRolledBack: return @"已回滚";
        case FKOperationTransactionStateRecoveryRequired: return @"需要人工恢复";
        default: return @"未知";
    }
}

+ (NSString *)stateCode:(FKOperationTransactionState)state {
    switch (state) {
        case FKOperationTransactionStateCreated: return @"created";
        case FKOperationTransactionStatePreflight: return @"preflight";
        case FKOperationTransactionStateGateChecking: return @"gate_checking";
        case FKOperationTransactionStateBackup: return @"backup";
        case FKOperationTransactionStateAwaitingConfirmation: return @"awaiting_confirmation";
        case FKOperationTransactionStateApplying: return @"applying";
        case FKOperationTransactionStateVerifying: return @"verifying";
        case FKOperationTransactionStateCompleted: return @"completed";
        case FKOperationTransactionStateFailed: return @"failed";
        case FKOperationTransactionStateRollback: return @"rollback";
        case FKOperationTransactionStateRolledBack: return @"rolled_back";
        case FKOperationTransactionStateRecoveryRequired: return @"recovery_required";
        default: return @"unknown";
    }
}

- (BOOL)transitionTo:(FKOperationTransactionState)to error:(NSError *_Nullable *_Nullable)error {
    if ([FKOperationStateMachine isTerminalState:self.state]) {
        if (error) {
            *error = [NSError errorWithDomain:FKOperationStateMachineErrorDomain
                                         code:FKOperationStateMachineErrorTerminal
                                     userInfo:@{NSLocalizedDescriptionKey: @"事务已处于终态，不可再流转"}];
        }
        return NO;
    }
    if (![FKOperationStateMachine canTransitionFrom:self.state to:to]) {
        if (error) {
            *error = [NSError errorWithDomain:FKOperationStateMachineErrorDomain
                                         code:FKOperationStateMachineErrorInvalidTransition
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"状态 %@ 不能流转到 %@",
                                                 [FKOperationStateMachine stateText:self.state],
                                                 [FKOperationStateMachine stateText:to]]}];
        }
        return NO;
    }
    _state = to;
    return YES;
}

- (void)reset {
    _state = FKOperationTransactionStateCreated;
}

@end
