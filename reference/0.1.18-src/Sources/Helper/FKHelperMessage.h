#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// v1 协议消息类型。
typedef NS_ENUM(NSInteger, FKHelperMessageType) {
    FKHelperMessageRequest = 0,   /// 请求
    FKHelperMessageResponse,      /// 响应
    FKHelperMessageEvent          /// 主动事件
};

/// v1 协议消息大小上限：1 MiB；具体阈值后续按插件清单与配置数据大小调整。
FOUNDATION_EXPORT const NSUInteger FKHelperMessageMaxPayloadBytes;
/// 请求时间戳允许偏移（秒），超出视为过期请求。
FOUNDATION_EXPORT const NSTimeInterval FKHelperMessageMaxAge;

/// 防重放 Nonce 缓存：记录会话内已使用的 nonce 与时间戳。
/// Nonce 与时间戳只辅助防重放，不能取代对端身份验证，也不单独保证通信安全。
@interface FKHelperNonceCache : NSObject

/// 记录 nonce；若已存在或时间戳过期返回 NO。
- (BOOL)adoptNonce:(NSString *)nonce timestamp:(NSTimeInterval)timestamp;
/// 清空缓存。
- (void)reset;

@end

/// v1 统一协议报文。这是协议格式模型，不代表当前设备已建立真实通信。
/// 字段：协议版本、请求标识、方法、消息类型、载荷、时间戳、防重放随机值。
@interface FKHelperMessage : NSObject <NSSecureCoding>

/// 协议主版本。
@property (nonatomic, assign) NSInteger protocolMajor;
/// 协议次版本。
@property (nonatomic, assign) NSInteger protocolMinor;
/// 请求 / 响应匹配标识（UUID）。
@property (nonatomic, copy) NSString *requestID;
/// 方法名（只读白名单内）。
@property (nonatomic, copy) NSString *method;
/// 消息类型。
@property (nonatomic, assign) FKHelperMessageType messageType;
/// 载荷字典。
@property (nonatomic, strong) NSDictionary *payload;
/// 时间戳。
@property (nonatomic, strong) NSDate *timestamp;
/// 防重放随机值。
@property (nonatomic, copy) NSString *nonce;
/// 响应状态文本（success / failure）；请求与事件为空。
@property (nonatomic, copy) NSString *responseStatus;
/// 响应错误描述字典；成功响应为空。
@property (nonatomic, strong, nullable) NSDictionary *errorPayload;

/// 序列化为 JSON 数据；失败返回 nil 并填 error。
- (nullable NSData *)JSONData:(NSError **)error;
/// 从 JSON 数据反序列化；非法数据返回 nil 并填 error。
+ (nullable instancetype)messageFromData:(NSData *)data error:(NSError **)error;

/// 本地结构校验：协议版本、请求标识、方法白名单、载荷大小与时间窗口。
/// 仅做结构与字段校验，不发起 IPC，不依据 nonce/timestamp 做身份认证。
- (BOOL)validateWithError:(NSError **)error;

/// 响应是否与本请求匹配（requestID 一致）。
- (BOOL)matchesResponse:(FKHelperMessage *)response;

/// 方法是否属于 v1 只读白名单。
+ (BOOL)isReadOnlyMethodWhitelisted:(NSString *)method;

@end

NS_ASSUME_NONNULL_END
