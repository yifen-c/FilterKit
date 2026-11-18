#import <Foundation/Foundation.h>
#import "FKOperationGate.h"
#import "FKOperationPolicy.h"

@class FKOperationCheck;

NS_ASSUME_NONNULL_BEGIN

/// 准入评估结论：汇总各项检查、策略与阻止原因。结论由 Gate 动态计算，
/// UI 不能直接把闸门置为通过；0.1.15 固定只读预演，不开放真实启停。
@interface FKOperationEligibility : NSObject

/// 操作模式（preview_only）
@property (nonatomic, copy) NSString *mode;
/// 是否具备操作资格（不存在 Failed / Blocked 项）
@property (nonatomic, assign) BOOL eligible;
/// 综合状态（ready / preview / blocked）
@property (nonatomic, copy) NSString *status;
/// 单项检查结果
@property (nonatomic, copy) NSArray<FKOperationCheck *> *checks;
/// 阻止 / 存疑原因列表
@property (nonatomic, copy) NSArray<NSString *> *blockReasons;
/// 生效策略
@property (nonatomic, strong) FKOperationPolicy *policy;
/// 准入决策结论。
@property (nonatomic, assign) FKOperationDecision decision;
/// 机器可读拒绝原因码列表（对齐 Gate 拒绝原因规范）。
@property (nonatomic, copy) NSArray<NSString *> *reasonCodes;
/// 目标 App Bundle ID（全局插件可空）。
@property (nonatomic, copy, nullable) NSString *appBundleID;

- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
