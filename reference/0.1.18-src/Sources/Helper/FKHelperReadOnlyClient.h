#import <Foundation/Foundation.h>
#import "FKHelperTransport.h"

NS_ASSUME_NONNULL_BEGIN

@class FKHelperCapabilities, FKHelperSession, FKHelperTrustReport, FKHelperIPCAuditEvent;

/// 生产环境只读 Helper 客户端。
/// 仅接受非 Mock、已连接的 Transport；所有响应必须通过报文结构、协议、方法、
/// Request ID 与响应状态校验。此客户端不包含任何写操作 API。
@interface FKHelperReadOnlyClient : NSObject

- (instancetype)initWithTransport:(nullable id<FKHelperTransport>)transport;
/// 仅在当前会话、信任报告与能力集合均满足只读条件时才允许发送请求。
- (instancetype)initWithTransport:(nullable id<FKHelperTransport>)transport
                           session:(nullable FKHelperSession *)session
                       trustReport:(nullable FKHelperTrustReport *)trustReport
                       capabilities:(nullable FKHelperCapabilities *)capabilities;

/// 仅当传输非 Mock 且底层明确报告连接时为 YES；不代表 Peer 已验证。
@property (nonatomic, readonly) BOOL connected;
/// 只有传输、会话、信任证据和只读能力全部满足时才为 YES。
@property (nonatomic, readonly) BOOL readyReadOnly;
/// 可连接到 FKAuditManager.appendHelperIPCAuditEvent:；事件不包含配置或文件正文。
@property (nonatomic, copy, nullable) void (^auditEventHandler)(FKHelperIPCAuditEvent *event);

- (void)requestHelperInfo:(void (^)(NSDictionary *_Nullable result, NSError *_Nullable error))completion;
- (void)requestHelperHealth:(void (^)(NSDictionary *_Nullable result, NSError *_Nullable error))completion;
- (void)requestCapabilities:(void (^)(FKHelperCapabilities *_Nullable capabilities, NSError *_Nullable error))completion;
- (void)requestPluginList:(void (^)(NSArray *_Nullable plugins, NSError *_Nullable error))completion;
- (void)requestPluginInfo:(NSString *)pluginID
              completion:(void (^)(NSDictionary *_Nullable info, NSError *_Nullable error))completion;
- (void)requestConfigurationSnapshot:(void (^)(NSDictionary *_Nullable snapshot, NSError *_Nullable error))completion;
- (void)disconnect;

@end

NS_ASSUME_NONNULL_END
