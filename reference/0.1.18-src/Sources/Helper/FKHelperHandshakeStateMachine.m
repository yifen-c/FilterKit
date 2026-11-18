#import "FKHelperHandshakeStateMachine.h"
#import <CoreFoundation/CoreFoundation.h>

static NSError *FKHandshakeStateError(NSString *reasonCode, NSString *reason) {
    return [NSError errorWithDomain:@"com.filterkit.handshake.state" code:1
                           userInfo:@{@"reasonCode": reasonCode ?: @"state_rejected",
                                      NSLocalizedDescriptionKey: reason ?: @"握手状态转换被拒绝"}];
}

@implementation FKHelperHandshakeStateMachine {
    NSLock *_lock;
    FKHelperHandshakePhase _phase;
    NSString *_failureReason;
}

- (instancetype)init {
    self = [super init];
    if (self) { _lock = [NSLock new]; _phase = FKHelperHandshakePhaseIdle; _failureReason = @""; }
    return self;
}

- (FKHelperHandshakePhase)phase { [_lock lock]; FKHelperHandshakePhase value = _phase; [_lock unlock]; return value; }
- (NSString *)failureReason { [_lock lock]; NSString *value = [_failureReason copy]; [_lock unlock]; return value; }

- (BOOL)advanceToPhase:(FKHelperHandshakePhase)phase evidence:(NSDictionary *)evidence error:(NSError **)error {
    NSDictionary<NSNumber *, NSString *> *required = @{
        @(FKHelperHandshakePhasePeerVerified): @"peer_verified",
        @(FKHelperHandshakePhaseProtocolNegotiated): @"protocol_negotiated",
        @(FKHelperHandshakePhaseTranscriptVerified): @"transcript_verified",
        @(FKHelperHandshakePhaseKeyDerived): @"key_derived",
        @(FKHelperHandshakePhaseClientConfirmed): @"client_confirmation_verified",
        @(FKHelperHandshakePhaseEstablished): @"helper_confirmation_verified"
    };
    [_lock lock];
    NSString *key = required[@(phase)];
    id raw = [evidence isKindOfClass:NSDictionary.class] ? evidence[key] : nil;
    BOOL strictTrue = [raw isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)raw) == CFBooleanGetTypeID() && [raw boolValue];
    BOOL valid = key != nil && _phase != FKHelperHandshakePhaseFailed && _phase != FKHelperHandshakePhaseExpired &&
        phase == _phase + 1 && strictTrue;
    if (!valid) {
        NSString *reasonCode = key == nil ? @"invalid_target_phase" :
            (phase != _phase + 1 ? @"invalid_phase_order" : @"required_evidence_missing");
        NSString *reason = key == nil ? @"目标状态非法" : (phase != _phase + 1 ? @"状态顺序非法" : @"缺少严格布尔验证证据");
        if (error) *error = FKHandshakeStateError(reasonCode, reason);
        [_lock unlock];
        return NO;
    }
    _phase = phase;
    [_lock unlock];
    return YES;
}

- (void)failWithReason:(NSString *)reason {
    [_lock lock];
    if (_phase != FKHelperHandshakePhaseEstablished && _phase != FKHelperHandshakePhaseExpired) {
        _phase = FKHelperHandshakePhaseFailed;
        _failureReason = ([reason isKindOfClass:NSString.class] && reason.length > 0) ? [reason copy] : @"handshake_failed";
    }
    [_lock unlock];
}

- (void)expire {
    [_lock lock];
    if (_phase != FKHelperHandshakePhaseFailed) _phase = FKHelperHandshakePhaseExpired;
    [_lock unlock];
}

- (void)reset {
    [_lock lock];
    _phase = FKHelperHandshakePhaseIdle;
    _failureReason = @"";
    [_lock unlock];
}
@end
