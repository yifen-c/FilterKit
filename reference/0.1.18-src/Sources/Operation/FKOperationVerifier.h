#import <Foundation/Foundation.h>

@class FKOperationTransaction;

NS_ASSUME_NONNULL_BEGIN

/// 配置验证结论。Helper 返回成功不代表配置已变更；必须重新读取配置比对目标状态后才能判定通过。
typedef NS_ENUM(NSInteger, FKVerificationStatus) {
    FKVerificationStatusNone = 0,   /// 尚未验证
    FKVerificationStatusPassed,      /// 重新读取到的实际配置与目标状态一致
    FKVerificationStatusFailed,      /// 实际配置与目标状态不一致
    FKVerificationStatusUnknown      /// 读取失败或证据不足，无法判定
};

/// 操作结果验证器：纯本地比对目标状态与重新读取到的实际状态；不连接 Helper、不读取进程加载信息。
@interface FKOperationVerifier : NSObject

/// 比对目标配置状态码与实际配置状态码；actualState 为空或 unknown 时归 Unknown。
+ (FKVerificationStatus)verifyTargetState:(NSString *)targetState actualState:(nullable NSString *)actualState;
+ (NSString *)codeForStatus:(FKVerificationStatus)status;
+ (NSString *)textForStatus:(FKVerificationStatus)status;

/// 依据事务内目标状态、操作后状态与哈希生成验证结论字典；不产生真实读取副作用。
+ (NSDictionary *)verifyTransaction:(nullable FKOperationTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
