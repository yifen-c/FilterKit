#import <Foundation/Foundation.h>

@class FKHelperIdentity;
@class FKHelperMetadata;
@class FKHelperTrustReport;

NS_ASSUME_NONNULL_BEGIN

/// 对端身份验证状态。连接成功不等于对端可信；证据不足时保持 Unverified，不得提升为 Verified。
typedef NS_ENUM(NSInteger, FKHelperPeerStatus) {
    FKHelperPeerUnknown = 0,      /// 未知
    FKHelperPeerNotConnected,    /// 未连接 / 连接已断开
    FKHelperPeerUnverified,       /// 已连接但对端身份证据不足
    FKHelperPeerVerified,         /// 对端身份经可信证据验证通过
    FKHelperPeerMismatch,         /// 身份标识 / Build 不匹配
    FKHelperPeerRejected          /// 清单不可信，拒绝该对端
};

/// 对端身份验证器：结合本地可信身份、发布清单、完整性与会话证据，判定当前会话对端是否可信。
/// 验证器无状态：会话变化后必须重新验证，不保留上一次会话的 Verified 结论。
@interface FKHelperPeerVerifier : NSObject

/// 验证指定身份 / 元数据 / 信任报告对应的对端。
/// @param identity 对端自报身份（待验证声明）；缺失返回 Unverified
/// @param metadata 候选元数据；缺失返回 Unverified
/// @param trustReport 本地信任汇总报告；未连接返回 NotConnected
- (FKHelperPeerStatus)verifyPeerIdentity:(nullable FKHelperIdentity *)identity
                                metadata:(nullable FKHelperMetadata *)metadata
                             trustReport:(nullable FKHelperTrustReport *)trustReport;

+ (NSString *)statusCodeForStatus:(FKHelperPeerStatus)status;
+ (NSString *)statusTextForStatus:(FKHelperPeerStatus)status;

@end

NS_ASSUME_NONNULL_END
