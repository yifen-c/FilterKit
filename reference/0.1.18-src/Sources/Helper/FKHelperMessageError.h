#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// v1 协议消息错误域。
extern NSErrorDomain const FKHelperMessageErrorDomain;

/// v1 协议消息错误码。与既有 FKHelperIPCErrorCode 区分；仅用于本地模型与状态记录，
/// 阶段一不建立真实连接、不发起端点请求。
typedef NS_ENUM(NSInteger, FKHelperMessageErrorCode) {
    FKHelperMessageErrorUnknown = 0,
    FKHelperMessageErrorInvalidMessage,
    FKHelperMessageErrorUnsupportedProtocol,
    FKHelperMessageErrorInvalidRequestID,
    FKHelperMessageErrorReplayDetected,
    FKHelperMessageErrorExpiredRequest,
    FKHelperMessageErrorUnauthorized,
    FKHelperMessageErrorUnsupportedMethod,
    FKHelperMessageErrorTimeout,
    FKHelperMessageErrorDisconnected,
    FKHelperMessageErrorPeerUnverified,
    FKHelperMessageErrorInvalidNonce
};

@interface FKHelperMessageError : NSObject

/// 错误码对应的可读描述。
+ (NSString *)descriptionForCode:(FKHelperMessageErrorCode)code;
/// 错误码对应的机器可读原因码。
+ (NSString *)reasonCodeForCode:(FKHelperMessageErrorCode)code;

@end

NS_ASSUME_NONNULL_END
