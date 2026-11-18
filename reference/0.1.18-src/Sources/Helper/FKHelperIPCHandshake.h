#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// IPC 连接状态机。阶段一无可信端点，正确状态为 Unavailable；不模拟已连接。
typedef NS_ENUM(NSInteger, FKHelperIPCStatus) {
    FKHelperIPCUnavailable = 0,       /// 未发现经过身份验证的 Helper 服务
    FKHelperIPCDisconnected,          /// 已断开
    FKHelperIPCConnecting,            /// 连接中
    FKHelperIPCConnected,             /// 已连接（且对端已验证、协议兼容）
    FKHelperIPCHandshakeFailed,       /// 握手失败
    FKHelperIPCIncompatible,          /// 协议版本不兼容
    FKHelperIPCPeerUnverified         /// 通信对端身份未验证
};

/// 握手请求报文：客户端向 Helper 声明自身版本与协议版本并请求能力清单。
@interface FKHelperIPCHandshakeRequest : NSObject

@property (nonatomic, copy) NSString *client;
@property (nonatomic, copy) NSString *clientVersion;
@property (nonatomic, assign) NSInteger protocolVersion;
@property (nonatomic, copy) NSString *request;

+ (instancetype)requestWithClientVersion:(NSString *)clientVersion protocolVersion:(NSInteger)protocolVersion;
- (NSDictionary *)JSONDictionary;

@end

/// 握手响应报文：Helper 回带身份、版本、协议版本、状态与能力清单。
@interface FKHelperIPCHandshakeResponse : NSObject

@property (nonatomic, copy) NSString *helperID;
@property (nonatomic, copy) NSString *helperVersion;
@property (nonatomic, assign) NSInteger protocolVersion;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSArray<NSString *> *capabilities;

+ (nullable instancetype)responseFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;
/// 本地结构与对端字段校验；不连接端点。error 为 nil 时结构合法。
- (BOOL)validateWithError:(NSError * _Nullable * _Nullable)error;

@end

@interface FKHelperIPCHandshake : NSObject

+ (NSString *)statusCodeForStatus:(FKHelperIPCStatus)status;
+ (NSString *)statusTextForStatus:(FKHelperIPCStatus)status;

@end

NS_ASSUME_NONNULL_END
