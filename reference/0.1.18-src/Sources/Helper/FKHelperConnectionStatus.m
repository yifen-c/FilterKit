#import "FKHelperConnectionStatus.h"

@implementation FKHelperConnectionStatusCodec

+ (NSString *)statusCodeForStatus:(FKHelperConnectionStatus)status {
    switch (status) {
        case FKHelperConnectionUnavailable:      return @"unavailable";
        case FKHelperConnectionConnecting:        return @"connecting";
        case FKHelperConnectionHandshaking:       return @"handshaking";
        case FKHelperConnectionVerifying:         return @"verifying";
        case FKHelperConnectionReadyReadOnly:     return @"ready_read_only";
        case FKHelperConnectionDisconnected:      return @"disconnected";
        case FKHelperConnectionTimeout:           return @"timeout";
        case FKHelperConnectionRejected:          return @"rejected";
        case FKHelperConnectionUnknown:
        default:                                  return @"unknown";
    }
}

+ (NSString *)statusTextForStatus:(FKHelperConnectionStatus)status {
    switch (status) {
        case FKHelperConnectionUnavailable:      return @"不可用";
        case FKHelperConnectionConnecting:        return @"连接中";
        case FKHelperConnectionHandshaking:       return @"握手协商中";
        case FKHelperConnectionVerifying:         return @"对端验证中";
        case FKHelperConnectionReadyReadOnly:     return @"已连接 · 只读模式";
        case FKHelperConnectionDisconnected:      return @"已断开";
        case FKHelperConnectionTimeout:            return @"超时";
        case FKHelperConnectionRejected:          return @"已拒绝";
        case FKHelperConnectionUnknown:
        default:                                  return @"未知";
    }
}

+ (BOOL)isReadOnlyReady:(FKHelperConnectionStatus)status {
    return status == FKHelperConnectionReadyReadOnly;
}

+ (BOOL)isTerminal:(FKHelperConnectionStatus)status {
    switch (status) {
        case FKHelperConnectionDisconnected:
        case FKHelperConnectionTimeout:
        case FKHelperConnectionRejected:
        case FKHelperConnectionUnavailable:
            return YES;
        default:
            return NO;
    }
}

@end
