#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 身份验证细化状态。无可信发布来源记录时保持 Unknown，不因 ID/版本符合预期而自动通过。
typedef NS_ENUM(NSInteger, FKHelperIdentityStatus) {
    FKHelperIdentityUnknown = 0,      /// 证据不足，无法判定
    FKHelperIdentityVerified,         /// 身份经可信发布记录确认
    FKHelperIdentityMismatch,         /// 标识与预期不符
    FKHelperIdentityIncomplete         /// 必要身份信息缺失
};

/// Helper 身份验证：核对候选路径、归属软件包与可追溯证据。
/// 文件存在或 LaunchDaemon Label 同名都不能单独证明身份；缺少官方渠道/版本匹配证据时不给通过。
@interface FKHelperIdentityVerifier : NSObject

/// 评估身份细化状态。reasons 追加未通过或存疑说明。
+ (FKHelperIdentityStatus)verifyIdentityStatusWithPath:(NSString *)path
                                              packageID:(NSString *)packageID
                                                version:(NSString *)version
                                             identifier:(nullable NSString *)identifier
                                                reasons:(NSMutableArray<NSString *> *)reasons;

/// 兼容旧接口：返回身份是否可视为已验证（仅 Verified 为 YES）。
+ (BOOL)verifyIdentityWithPath:(NSString *)path
                     packageID:(NSString *)packageID
                       version:(NSString *)version
                       reasons:(NSMutableArray<NSString *> *)reasons;

@end

NS_ASSUME_NONNULL_END
