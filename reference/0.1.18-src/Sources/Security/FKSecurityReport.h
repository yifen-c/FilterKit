#import <Foundation/Foundation.h>
#import "FKSecurityEvent.h"

/// 安全报告：汇总一段时间内的安全事件、结论分布与证据来源，保留验证时间，
/// 避免把旧的验证结果误当成当前状态。
@interface FKSecurityReport : NSObject

/// 报告包含的事件
@property (nonatomic, copy) NSArray<FKSecurityEvent *> *events;
/// 报告生成时间
@property (nonatomic, copy) NSDate *generatedAt;
/// 扫描标识（与报告 scan_id 关联）
@property (nonatomic, copy) NSString *scanID;
/// 环境评估结论快照
@property (nonatomic, strong) NSDictionary *environment;
/// 注入器画像快照
@property (nonatomic, strong) NSDictionary *injector;
/// Helper 信任结论快照
@property (nonatomic, strong) NSDictionary *helperTrust;
/// 安全准入结论快照
@property (nonatomic, strong) NSDictionary *securityGate;
/// 自动化测试摘要
@property (nonatomic, strong) NSDictionary *testSummary;

+ (instancetype)reportWithEvents:(NSArray<FKSecurityEvent *> *)events;
- (NSDictionary *)JSONDictionary;

@end
