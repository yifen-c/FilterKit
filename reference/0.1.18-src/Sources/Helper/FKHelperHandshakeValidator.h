#import <Foundation/Foundation.h>

@class FKHelperIPCHandshakeResponse;
@class FKHelperTrustReport;

NS_ASSUME_NONNULL_BEGIN

/// 握手校验器：在建立会话前核对请求 / 响应一致性、协议版本、身份、清单、对端与能力边界。
/// 校验只依据本地可信证据与报文结构；握手响应中的身份字段属于待验证声明，必须与本地证据比对。
@interface FKHelperHandshakeValidator : NSObject

/// 校验握手请求与响应。
/// @param requestID 本次请求标识
/// @param nonce 本次握手随机值
/// @param timestamp 请求时间戳（Unix 秒）；0 表示未提供，不做时间窗判定
/// @param response Helper 握手响应；缺失计入拒绝
/// @param trustReport 本地信任汇总报告
/// @return 机器可读拒绝原因码数组；空数组表示通过
- (NSArray<NSString *> *)rejectReasonsForRequestID:(nullable NSString *)requestID
                                              nonce:(nullable NSString *)nonce
                                          timestamp:(NSTimeInterval)timestamp
                                           response:(nullable FKHelperIPCHandshakeResponse *)response
                                        trustReport:(nullable FKHelperTrustReport *)trustReport;

@end

NS_ASSUME_NONNULL_END
