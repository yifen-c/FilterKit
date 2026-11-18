#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// IPC 错误分类。仅用于本地模型与状态记录；阶段一不建立真实连接，不发起端点请求。
typedef NS_ENUM(NSInteger, FKHelperIPCErrorCode) {
    FKHelperIPCErrorNone = 0,              /// 无错误
    FKHelperIPCErrorUnavailable,           /// 无可信 Helper 端点
    FKHelperIPCErrorHandshakeFailed,      /// 握手失败
    FKHelperIPCErrorIncompatible,         /// 协议版本不兼容
    FKHelperIPCErrorPeerUnverified,       /// 通信对端身份未验证
    FKHelperIPCErrorTimeout,               /// 通信超时
    FKHelperIPCErrorMalformed              /// 报文结构非法
};

@interface FKHelperIPCError : NSObject

+ (NSString *)descriptionForCode:(FKHelperIPCErrorCode)code;

@end

NS_ASSUME_NONNULL_END
