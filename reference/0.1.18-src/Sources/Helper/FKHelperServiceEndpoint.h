#import <Foundation/Foundation.h>
#import "FKHelperDiscovery.h"

NS_ASSUME_NONNULL_BEGIN

/// Helper 服务端点候选：记录服务名、归属 Helper 标识、发现状态与证据来源。
/// 端点模型只描述“发现了什么候选”，不构成身份可信、清单可信或完整性通过的结论；
/// 只有完整信任验证流程通过后才会进入 Verified。
@interface FKHelperServiceEndpoint : NSObject

/// 服务名（launchd 服务名 / 可执行文件名 / 路径）。
@property (nonatomic, copy) NSString *serviceName;
/// 候选自报或采集到的 Helper 标识；未匹配预期标识时可为空。
@property (nonatomic, copy, nullable) NSString *helperID;
/// 发现状态（复用 FKHelperDiscoveryStatus：NotFound / Found / Incomplete / Invalid / Verified）。
@property (nonatomic, assign) FKHelperDiscoveryStatus status;
/// 证据来源：filesystem_metadata / launchd_registration / system_tool / unknown。
@property (nonatomic, copy) NSString *source;
/// 机器可读拒绝或降级原因码。
@property (nonatomic, copy, nullable) NSString *reasonCode;

- (instancetype)initWithServiceName:(NSString *)serviceName
                            helperID:(nullable NSString *)helperID
                              status:(FKHelperDiscoveryStatus)status
                              source:(NSString *)source
                          reasonCode:(nullable NSString *)reasonCode;

- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
