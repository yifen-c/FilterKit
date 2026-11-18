#import "FKHelperMessageError.h"

NSErrorDomain const FKHelperMessageErrorDomain = @"com.filterkit.helper.message";

@implementation FKHelperMessageError

+ (NSString *)descriptionForCode:(FKHelperMessageErrorCode)code {
    switch (code) {
        case FKHelperMessageErrorInvalidMessage:        return @"报文结构非法";
        case FKHelperMessageErrorUnsupportedProtocol:  return @"协议版本不兼容";
        case FKHelperMessageErrorInvalidRequestID:     return @"请求标识缺失或非法";
        case FKHelperMessageErrorReplayDetected:       return @"检测到重复请求（重放）";
        case FKHelperMessageErrorExpiredRequest:      return @"请求已过期";
        case FKHelperMessageErrorUnauthorized:         return @"未授权";
        case FKHelperMessageErrorUnsupportedMethod:    return @"方法不在只读白名单内";
        case FKHelperMessageErrorTimeout:              return @"通信超时";
        case FKHelperMessageErrorDisconnected:        return @"连接已断开";
        case FKHelperMessageErrorPeerUnverified:       return @"通信对端身份未验证";
        case FKHelperMessageErrorInvalidNonce:          return @"请求缺少有效 Nonce";
        case FKHelperMessageErrorUnknown:
        default:                                       return @"未知协议错误";
    }
}

+ (NSString *)reasonCodeForCode:(FKHelperMessageErrorCode)code {
    switch (code) {
        case FKHelperMessageErrorInvalidMessage:        return @"invalid_message";
        case FKHelperMessageErrorUnsupportedProtocol:   return @"unsupported_protocol";
        case FKHelperMessageErrorInvalidRequestID:       return @"invalid_request_id";
        case FKHelperMessageErrorReplayDetected:         return @"replay_detected";
        case FKHelperMessageErrorExpiredRequest:        return @"expired_request";
        case FKHelperMessageErrorUnauthorized:          return @"unauthorized";
        case FKHelperMessageErrorUnsupportedMethod:     return @"unsupported_method";
        case FKHelperMessageErrorTimeout:               return @"timeout";
        case FKHelperMessageErrorDisconnected:          return @"disconnected";
        case FKHelperMessageErrorPeerUnverified:        return @"peer_unverified";
        case FKHelperMessageErrorInvalidNonce:           return @"invalid_nonce";
        case FKHelperMessageErrorUnknown:
        default:                                         return @"unknown";
    }
}

@end
