#import <Foundation/Foundation.h>

/// 结构化 Helper 请求报文模型。只做结构组织与本地校验，不发起真实 IPC；
/// request_id / timestamp / nonce 为协议辅助字段，不构成身份认证。
@interface FKIPCRequest : NSObject

/// 协议版本
@property (nonatomic, assign) NSInteger protocolVersion;
/// 请求唯一标识
@property (nonatomic, copy) NSString *requestID;
/// 白名单操作名
@property (nonatomic, copy) NSString *operation;
/// 插件标识
@property (nonatomic, copy) NSString *pluginID;
/// 时间戳（Unix 秒）
@property (nonatomic, assign) NSTimeInterval timestamp;
/// 防重放随机值（仅记录与去重依据；nonce 缓存去重与窗口校验待接入可信端点时实现）
@property (nonatomic, copy) NSString *nonce;
/// 授权上下文（由可信认证机制填充；本期为空）
@property (nonatomic, copy) NSString *authorization;

/// 依据插件与白名单操作构造请求，自动生成 requestID / nonce / 时间戳。
+ (instancetype)requestWithPluginID:(NSString *)pluginID operation:(NSString *)operation;
+ (instancetype)requestFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

/// 本地结构与白名单校验；不连接端点。error 为 nil 时表示结构合法。
- (BOOL)validateWithError:(NSError **)error;

@end
