#import "FKHelperSessionLifecycle.h"
#import "FKHelperKeyLifecycle.h"
#import <math.h>

@implementation FKHelperSessionLifecycle {
    NSLock *_lock;
    NSTimeInterval _maximumLifetime;
    NSTimeInterval _idleTimeout;
    NSDate *_lastActivityAt;
    NSDate *_expiresAt;
    FKHelperManagedSessionState _state;
    NSString *_sessionID;
    NSString *_terminalReason;
    FKHelperKeyLifecycle *_keyLifecycle;
}
- (instancetype)init { return [self initWithMaximumLifetime:3600 idleTimeout:300]; }
- (instancetype)initWithMaximumLifetime:(NSTimeInterval)maximumLifetime idleTimeout:(NSTimeInterval)idleTimeout {
    return [self initWithMaximumLifetime:maximumLifetime idleTimeout:idleTimeout keyLifecycle:nil];
}
- (instancetype)initWithMaximumLifetime:(NSTimeInterval)maximumLifetime
                            idleTimeout:(NSTimeInterval)idleTimeout
                           keyLifecycle:(FKHelperKeyLifecycle *)keyLifecycle {
    self = [super init];
    if (self) {
        _lock = [NSLock new];
        _maximumLifetime = (maximumLifetime >= 60 && maximumLifetime <= 86400) ? maximumLifetime : 0;
        _idleTimeout = (idleTimeout >= 10 && idleTimeout <= 3600) ? idleTimeout : 0;
        _state = FKHelperManagedSessionStateEmpty; _sessionID = @""; _terminalReason = @"";
        _keyLifecycle = keyLifecycle;
    }
    return self;
}
- (FKHelperManagedSessionState)state { [_lock lock]; id v = @(_state); [_lock unlock]; return [v integerValue]; }
- (NSString *)sessionID { [_lock lock]; NSString *v = [_sessionID copy]; [_lock unlock]; return v; }
- (NSString *)terminalReason { [_lock lock]; NSString *v = [_terminalReason copy]; [_lock unlock]; return v; }
- (BOOL)beginSessionWithID:(NSString *)sessionID peerBindingVerified:(BOOL)peerVerified
 clientConfirmationVerified:(BOOL)clientConfirmed helperConfirmationVerified:(BOOL)helperConfirmed date:(NSDate *)date {
    if (![sessionID isKindOfClass:NSString.class] || sessionID.length == 0 || sessionID.length > 128 ||
        ![date isKindOfClass:NSDate.class] || !isfinite(date.timeIntervalSince1970) || _maximumLifetime <= 0 || _idleTimeout <= 0 ||
        !peerVerified || !clientConfirmed || !helperConfirmed) return NO;
    [_lock lock];
    if (_state == FKHelperManagedSessionStateActive) { [_lock unlock]; return NO; }
    _sessionID = [sessionID copy]; _lastActivityAt = date;
    _expiresAt = [date dateByAddingTimeInterval:_maximumLifetime];
    _terminalReason = @""; _state = FKHelperManagedSessionStateActive;
    [_lock unlock];
    return YES;
}
- (BOOL)expireIfNeededAtDate:(NSDate *)date {
    if (_state != FKHelperManagedSessionStateActive) return NO;
    if ([date compare:_lastActivityAt] == NSOrderedAscending) {
        // 系统时钟倒退时不延长会话，直接失效并要求重新握手。
        _state = FKHelperManagedSessionStateInvalidated;
        _terminalReason = @"clock_rollback";
        [_keyLifecycle revokeActiveKey];
        _sessionID = @"";
        return YES;
    }
    if ([date compare:_expiresAt] != NSOrderedAscending ||
        [date timeIntervalSinceDate:_lastActivityAt] >= _idleTimeout) {
        _state = FKHelperManagedSessionStateExpired; _terminalReason = @"session_timeout"; _sessionID = @"";
        [_keyLifecycle revokeActiveKey];
        return YES;
    }
    return NO;
}
- (BOOL)touchAtDate:(NSDate *)date {
    if (![date isKindOfClass:NSDate.class] || !isfinite(date.timeIntervalSince1970)) return NO;
    [_lock lock];
    BOOL active = (_state == FKHelperManagedSessionStateActive) && ![self expireIfNeededAtDate:date];
    if (active) _lastActivityAt = date;
    [_lock unlock];
    return active;
}
- (BOOL)isActiveAtDate:(NSDate *)date {
    if (![date isKindOfClass:NSDate.class] || !isfinite(date.timeIntervalSince1970)) return NO;
    [_lock lock]; BOOL active = (_state == FKHelperManagedSessionStateActive) && ![self expireIfNeededAtDate:date]; [_lock unlock]; return active;
}
- (void)invalidateWithReason:(NSString *)reason {
    [_lock lock];
    if (_state == FKHelperManagedSessionStateActive) {
        _state = FKHelperManagedSessionStateInvalidated;
        _terminalReason = ([reason isKindOfClass:NSString.class] && reason.length > 0) ? [reason copy] : @"session_invalidated";
        _sessionID = @"";
        [_keyLifecycle revokeActiveKey];
    }
    [_lock unlock];
}
@end
