#import <Foundation/Foundation.h>
#import "FKHelperServiceEndpoint.h"

NS_ASSUME_NONNULL_BEGIN

/// Helper 服务发现判定器：把扫描候选映射为服务端点候选。
/// 严格区分“发现候选”与“可信 Helper”：系统工具、标识不符、元数据缺失一律降级；
/// 本判定器不连接未知服务，也不自行产生 Verified 结论（Verified 由后续信任流程汇总）。
@interface FKHelperServiceDiscovery : NSObject

/// 依据单个候选字典构造端点候选；无效候选返回 NotFound 端点。
+ (FKHelperServiceEndpoint *)endpointForCandidate:(nullable NSDictionary *)candidate;

/// 批量构造端点候选，保持候选顺序。
+ (NSArray<FKHelperServiceEndpoint *> *)endpointsForCandidates:(NSArray<NSDictionary *> *)candidates;

/// 生成可导出的发现证据报告。Found 仅代表候选形态匹配，不代表身份可信或 IPC 可用。
+ (NSDictionary *)discoveryReportForCandidates:(NSArray<NSDictionary *> *)candidates;

@end

NS_ASSUME_NONNULL_END
