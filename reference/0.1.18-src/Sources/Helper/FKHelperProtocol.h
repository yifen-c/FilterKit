#import <Foundation/Foundation.h>

/// RootHelper 通信错误域与错误码。
extern NSErrorDomain const FKHelperErrorDomain;

typedef NS_ENUM(NSInteger, FKHelperErrorCode) {
    FKHelperErrorUnavailable = 1,        /// 未检测到可用且已验证的 Helper
    FKHelperErrorUnauthorized,           /// 身份或授权未通过
    FKHelperErrorUnknownOperation,      /// 操作不在白名单内
    FKHelperErrorPathOutOfBounds,       /// 目标路径越出可信根
    FKHelperErrorInvalidRequest,        /// 请求字段不合法
    FKHelperErrorTimeout,               /// 通信超时
    FKHelperErrorIncompatible           /// 注入器或插件格式不兼容
};

/// Helper 允许的白名单操作标识。App 只能传入这些预定义操作，不能传入任意 shell 命令或脚本。
typedef NS_ENUM(NSInteger, FKHelperOperation) {
    FKHelperOperationGetStatus = 0,
    FKHelperOperationValidate,
    FKHelperOperationEnable,
    FKHelperOperationDisable,
    FKHelperOperationVerify,
    FKHelperOperationRestore
};

/// 白名单操作名（用于审计与协议报文）。
FOUNDATION_EXPORT NSString *const FKHelperOperationNameGetStatus;
FOUNDATION_EXPORT NSString *const FKHelperOperationNameValidate;
FOUNDATION_EXPORT NSString *const FKHelperOperationNameEnable;
FOUNDATION_EXPORT NSString *const FKHelperOperationNameDisable;
FOUNDATION_EXPORT NSString *const FKHelperOperationNameVerify;
FOUNDATION_EXPORT NSString *const FKHelperOperationNameRestore;

/// 返回白名单操作对应的方法名；非白名单返回 nil。
NSString *FKHelperOperationName(FKHelperOperation operation);
/// 判断操作名是否在白名单内。
BOOL FKHelperOperationIsAllowed(NSString *operationName);

/// 当前受控协议版本。
FOUNDATION_EXPORT const NSInteger FKHelperProtocolVersion;
/// 请求时间戳允许偏移（秒），超出视为重放或过期请求。
FOUNDATION_EXPORT const NSTimeInterval FKHelperRequestMaxAge;

/// 预期 Helper 标识（形态比对参考）。标识匹配不等于身份可信；身份仍须由可信发布记录与签名链确认。
FOUNDATION_EXPORT NSString *const FKHelperExpectedHelperIdentifier;

/// 校验结构化请求报文：协议版本、请求 ID、白名单操作、插件 ID 与时间戳窗口。
/// 仅做结构与字段校验，不发起 IPC；不依据 timestamp/request_id 做身份认证。
BOOL FKHelperValidateRequest(NSDictionary *request, NSError **error);

/// 校验结构化响应报文：协议版本、请求 ID 回带、状态与操作一致。
BOOL FKHelperValidateResponse(NSDictionary *response, NSError **error);
