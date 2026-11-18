#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// IPC 与握手安全审计动作。来源字段区分真实 IPC、Mock 与未实现状态。
typedef NS_ENUM(NSInteger, FKAuditHelperIPCAction) {
    FKAuditHelperIPCConnect = 0,
    FKAuditHelperIPCDisconnect,
    FKAuditHelperIPCHandshake,
    FKAuditHelperIPCPeerVerify,
    FKAuditHelperIPCCapabilityFetch,
    FKAuditHelperIPCPluginList,
    FKAuditHelperIPCPluginInspect,
    FKAuditHelperIPCConfigurationRead,
    FKAuditHelperIPCRejected,
    FKAuditHelperIPCInfoRead,
    FKAuditHelperIPCHealthRead,
    FKAuditHelperIPCPeerBinding,
    FKAuditHelperIPCKeyConfirmation,
    FKAuditHelperIPCHandshakeState,
    FKAuditHelperIPCSessionExpired
};

/// 一次 Helper IPC 审计事件的本地记录模型。仅保存动作、结果与必要元数据；
/// 不写入完整敏感配置或文件内容。真实持久化依赖环境，本地不伪造落库结果。
@interface FKHelperIPCAuditEvent : NSObject

@property (nonatomic, copy) NSString *eventID;
@property (nonatomic, strong) NSDate *timestamp;
/// 事件来源：real_ipc / mock / unsupported。
@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) FKAuditHelperIPCAction action;
/// 结果：success / failed / rejected。
@property (nonatomic, copy) NSString *result;
@property (nonatomic, copy, nullable) NSString *helperID;
@property (nonatomic, copy, nullable) NSString *buildID;
@property (nonatomic, copy, nullable) NSString *requestID;
@property (nonatomic, copy, nullable) NSString *sessionID;
@property (nonatomic, copy, nullable) NSString *reasonCode;
/// 本次返回记录数量；不保存记录正文。
@property (nonatomic, assign) NSUInteger recordCount;

- (NSDictionary *)JSONDictionary;
+ (nullable instancetype)eventFromDictionary:(nullable NSDictionary *)dictionary;

+ (NSString *)actionCode:(FKAuditHelperIPCAction)action;
+ (NSString *)actionText:(FKAuditHelperIPCAction)action;

@end

NS_ASSUME_NONNULL_END
