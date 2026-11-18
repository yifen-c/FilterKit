#import <Foundation/Foundation.h>
@class FKHelperPeerBinding, FKHelperSessionKey, FKHelperKeyLifecycle;
@class FKHelperHandshakeStateMachine, FKHelperSessionLifecycle, FKHelperKeyConfirmation, FKAuditManager;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FKHelperAuthenticatedSessionState) {
    FKHelperAuthenticatedSessionStateIdle = 0,
    FKHelperAuthenticatedSessionStateHandshaking,
    FKHelperAuthenticatedSessionStateEstablished,
    FKHelperAuthenticatedSessionStateExpired,
    FKHelperAuthenticatedSessionStateInvalidated,
    FKHelperAuthenticatedSessionStateFailed
};

/// 统一协调 Peer 绑定、握手状态、双向密钥确认与会话密钥生命周期。
/// 该类只管理本地认证状态，不代表真实 IPC 或系统 Peer 凭据已验证。
@interface FKHelperAuthenticatedSessionManager : NSObject
@property (nonatomic, readonly) FKHelperAuthenticatedSessionState state;
@property (nonatomic, copy, readonly) NSString *activeSessionID;
@property (nonatomic, copy, readonly) NSString *lastFailureReason;
@property (nonatomic, readonly) BOOL readOnlySessionEstablished;

- (instancetype)initWithAuditManager:(nullable FKAuditManager *)auditManager
                       keyLifecycle:(nullable FKHelperKeyLifecycle *)keyLifecycle
                     maximumLifetime:(NSTimeInterval)maximumLifetime
                          idleTimeout:(NSTimeInterval)idleTimeout NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// 建立会话：需匹配预期 Helper 身份，并验证客户端与 Helper 两个角色的确认码。
/// source 仅接受 mock / unsupported；真实 IPC 必须由独立 Transport 提供真实证据。
- (nullable FKHelperSessionKey *)createSessionKeyAtDate:(NSDate *)date;

- (BOOL)establishWithPeerBinding:(FKHelperPeerBinding *)binding
              expectedHelperID:(NSString *)expectedHelperID
             expectedBuildID:(NSString *)expectedBuildID
        expectedCredentialDigest:(NSString *)expectedCredentialDigest
                         key:(FKHelperSessionKey *)sessionKey
                  clientProof:(NSString *)clientProof
                  helperProof:(NSString *)helperProof
                       source:(NSString *)source
                        date:(NSDate *)date
                       error:(NSError **)error;

/// 对活跃会话触达；超时或时钟倒退会撤销密钥并审计。
- (BOOL)touchAtDate:(NSDate *)date;
/// 断线、会话替换或安全异常统一走失效路径。
- (void)invalidateWithReason:(NSString *)reason;
/// 主动检查绝对寿命与空闲超时。
- (BOOL)expireIfNeededAtDate:(NSDate *)date;

@end
NS_ASSUME_NONNULL_END
