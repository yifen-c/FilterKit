#import <Foundation/Foundation.h>
#import "FKHelperTrust.h"

@class FKHelperTrustStore;

/// Helper 信任综合评估：汇总身份、签名、权限与 IPC 证据，独立判定各级状态。
/// 状态不按顺序自动推进：发现不等于身份通过，签名有效也不代表权限或操作安全；
/// 无可信锚点时保守降级，不臆断 Passed。
@interface FKHelperTrustEvaluator : NSObject

/// 依据候选字典与可信策略生成信任报告。
/// @param candidates 扫描发现的 Helper 候选字典数组
/// @param store 可信锚点策略；传入 nil 时按无可信锚点处理
+ (FKHelperTrustReport *)evaluateCandidates:(NSArray<NSDictionary *> *)candidates
                                       store:(FKHelperTrustStore *)store;

@end
