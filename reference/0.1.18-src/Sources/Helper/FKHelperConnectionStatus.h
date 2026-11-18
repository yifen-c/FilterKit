#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 会话连接状态。区别于底层传输状态：覆盖握手、对端验证、只读就绪与异常终态。
/// ReadyReadOnly 表示通过验证后进入的只读会话；任何异常或断开都不得保留旧的 ReadyReadOnly。
typedef NS_ENUM(NSInteger, FKHelperConnectionStatus) {
    FKHelperConnectionUnknown = 0,        /// 未知
    FKHelperConnectionUnavailable,        /// 无可用端点
    FKHelperConnectionConnecting,          /// 连接中
    FKHelperConnectionHandshaking,          /// 握手协商中
    FKHelperConnectionVerifying,           /// 对端身份 / 信任验证中
    FKHelperConnectionReadyReadOnly,        /// 已通过验证，进入只读会话
    FKHelperConnectionDisconnected,         /// 已断开
    FKHelperConnectionTimeout,              /// 超时
    FKHelperConnectionRejected              /// 被安全门槛拒绝
};

/// 连接状态码 / 文案工具宿主类；与上方枚举 `FKHelperConnectionStatus` 区分命名，避免符号重定义。
@interface FKHelperConnectionStatusCodec : NSObject

+ (NSString *)statusCodeForStatus:(FKHelperConnectionStatus)status;
+ (NSString *)statusTextForStatus:(FKHelperConnectionStatus)status;
/// 是否处于只读就绪会话。
+ (BOOL)isReadOnlyReady:(FKHelperConnectionStatus)status;
/// 是否为终态（断开 / 超时 / 拒绝 / 不可用）。
+ (BOOL)isTerminal:(FKHelperConnectionStatus)status;

@end

NS_ASSUME_NONNULL_END
