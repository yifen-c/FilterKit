#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 会话状态机。正常完成进入 ReadyReadOnly（只读会话）；任何异常或断开都不得保留旧的 ReadyReadOnly。
typedef NS_ENUM(NSInteger, FKHelperSessionState) {
    FKHelperSessionDisconnected = 0,  /// 未连接
    FKHelperSessionConnecting,         /// 连接中
    FKHelperSessionHandshaking,        /// 握手协商中
    FKHelperSessionVerifying,          /// 对端 / 信任验证中
    FKHelperSessionReadyReadOnly,       /// 已通过验证，只读会话就绪
    FKHelperSessionFailed,             /// 会话失败
    FKHelperSessionClosed              /// 已关闭（断开后撤销授权）
};

/// 一次 Helper 会话的上下文与状态流转。会话不缓存上一连接的授权状态；
/// 断开或关闭后必须撤销 peerVerified，正在执行的请求随之失败。
@interface FKHelperSession : NSObject

/// 当前会话状态。
@property (nonatomic, assign) FKHelperSessionState state;
/// 本次会话请求标识。
@property (nonatomic, copy, nullable) NSString *sessionID;
@property (nonatomic, copy, nullable) NSString *requestID;
/// 本次会话随机值。
@property (nonatomic, copy, nullable) NSString *nonce;
/// 会话发起时间。
@property (nonatomic, strong, nullable) NSDate *startedAt;
/// 对端是否已验证；关闭 / 断开时重置为 NO。
@property (nonatomic, assign) BOOL peerVerified;

/// 切换会话状态。
- (void)transitionToState:(FKHelperSessionState)state;
/// 关闭会话：状态置 Closed 并撤销对端验证结论。
- (void)closeSession;
/// 是否处于只读就绪会话。
- (BOOL)isReadOnlyReady;

+ (NSString *)stateCodeForState:(FKHelperSessionState)state;
+ (NSString *)stateTextForState:(FKHelperSessionState)state;

@end

NS_ASSUME_NONNULL_END
