#import <Foundation/Foundation.h>

/// 结构化 Helper 响应报文模型。状态区分成功、失败、未授权、超时与版本不兼容；
/// 响应只作为协议校验样例，0.1.4 不建立真实特权连接。
@interface FKIPCResponse : NSObject

/// 协议版本
@property (nonatomic, assign) NSInteger protocolVersion;
/// 回带的请求标识
@property (nonatomic, copy) NSString *requestID;
/// 响应状态（success / failed / unauthorized / timeout / incompatible）
@property (nonatomic, copy) NSString *status;
/// 结果负载
@property (nonatomic, strong) NSDictionary *result;
/// 错误信息（code / message）；成功时为空
@property (nonatomic, copy) NSDictionary *error;

+ (instancetype)responseWithRequestID:(NSString *)requestID status:(NSString *)status;
+ (instancetype)responseFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

/// 本地结构校验；不连接端点。
- (BOOL)validateWithError:(NSError **)error;

@end
