#import <Foundation/Foundation.h>

@class FKHelperTrustReport;
@class FKHelperCapabilities;

NS_ASSUME_NONNULL_BEGIN

/// 能力准入评估器：独立于 UI，综合信任链与能力白名单判定某能力是否可执行。
/// 判断条件（全部满足才放行）：Helper 身份可信、发布清单已验证、二进制完整性已验证、
/// IPC 对端/通道已验证、协议兼容、能力存在且属于只读白名单、目标范围允许。
/// 0.1.15 未连接真实 Helper，真实 Helper 能力一律不可用；写能力与未知能力直接拒绝。
@interface FKCapabilityEvaluator : NSObject

/// 最近一次判定被拒绝的机器可读原因码；放行时为空数组。
@property (nonatomic, copy, readonly) NSArray<NSString *> *denyReasons;

/// 评估指定能力是否可执行。
/// @param capability 能力键（如 helper.info / plugin.list）
/// @param report Helper 信任报告；传入 nil 视为无可信证据
/// @param capabilities Helper 已登记能力集合；传入 nil 视为未登记
- (BOOL)canPerformCapability:(NSString *)capability
                  trustReport:(nullable FKHelperTrustReport *)report
                 capabilities:(nullable FKHelperCapabilities *)capabilities;

@end

NS_ASSUME_NONNULL_END
