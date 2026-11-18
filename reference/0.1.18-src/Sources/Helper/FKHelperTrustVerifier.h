#import <Foundation/Foundation.h>
#import "FKHelperTrust.h"

/// Helper 信任编排：依次完成身份、签名、权限评估，结合 IPC 状态给出逐级信任结论。
/// 0.1.2 不连接真实 Helper；所有结论基于本地只读证据，证据不足即保守降级。
@interface FKHelperTrustVerifier : NSObject

/// 依据扫描报告中的候选字典数组生成信任报告。
+ (FKHelperTrustReport *)evaluateCandidates:(NSArray<NSDictionary *> *)candidates;

@end
