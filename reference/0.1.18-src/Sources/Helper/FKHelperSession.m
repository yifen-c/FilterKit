#import "FKHelperSession.h"

@implementation FKHelperSession

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = FKHelperSessionDisconnected;
        _startedAt = [NSDate date];
    }
    return self;
}

- (void)transitionToState:(FKHelperSessionState)state {
    _state = state;
    // 进入失败 / 断开 / 关闭态时，撤销对端验证结论。
    if (state == FKHelperSessionFailed || state == FKHelperSessionDisconnected || state == FKHelperSessionClosed) {
        _peerVerified = NO;
    }
}

- (void)closeSession {
    _state = FKHelperSessionClosed;
    _peerVerified = NO;
}

- (BOOL)isReadOnlyReady {
    return self.state == FKHelperSessionReadyReadOnly && self.peerVerified;
}

+ (NSString *)stateCodeForState:(FKHelperSessionState)state {
    switch (state) {
        case FKHelperSessionConnecting:       return @"connecting";
        case FKHelperSessionHandshaking:      return @"handshaking";
        case FKHelperSessionVerifying:        return @"verifying";
        case FKHelperSessionReadyReadOnly:    return @"ready_read_only";
        case FKHelperSessionFailed:           return @"failed";
        case FKHelperSessionClosed:           return @"closed";
        case FKHelperSessionDisconnected:
        default:                              return @"disconnected";
    }
}

+ (NSString *)stateTextForState:(FKHelperSessionState)state {
    switch (state) {
        case FKHelperSessionConnecting:       return @"连接中";
        case FKHelperSessionHandshaking:      return @"握手协商中";
        case FKHelperSessionVerifying:        return @"对端验证中";
        case FKHelperSessionReadyReadOnly:    return @"只读会话就绪";
        case FKHelperSessionFailed:           return @"会话失败";
        case FKHelperSessionClosed:           return @"已关闭";
        case FKHelperSessionDisconnected:
        default:                              return @"未连接";
    }
}

@end
