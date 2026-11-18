#import "FKHelperIPCError.h"

@implementation FKHelperIPCError

+ (NSString *)descriptionForCode:(FKHelperIPCErrorCode)code {
    switch (code) {
        case FKHelperIPCErrorNone: return @"无错误";
        case FKHelperIPCErrorUnavailable: return @"无可信 Helper 端点";
        case FKHelperIPCErrorHandshakeFailed: return @"握手失败";
        case FKHelperIPCErrorIncompatible: return @"协议版本不兼容";
        case FKHelperIPCErrorPeerUnverified: return @"通信对端身份未验证";
        case FKHelperIPCErrorTimeout: return @"通信超时";
        case FKHelperIPCErrorMalformed: return @"报文结构非法";
    }
    return @"未知错误";
}

@end
