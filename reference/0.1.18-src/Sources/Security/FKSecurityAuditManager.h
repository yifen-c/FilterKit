#import <Foundation/Foundation.h>
#import "FKSecurityEvidenceStore.h"
#import "FKSecurityReport.h"

/// 安全审计门面：集中记录环境、注入器、Helper、IPC 与准入判断证据，生成安全报告。
/// 记录追加写入，历史不可被普通流程修改；0.1.5 接入扫描节点并汇总结构化快照。
@interface FKSecurityAuditManager : NSObject

/// 底层证据存储
@property (nonatomic, strong, readonly) FKSecurityEvidenceStore *store;
/// 扫描标识；生成报告时写入 scan_id
@property (nonatomic, copy) NSString *scanID;
/// 环境 / 注入器 / Helper / 闸门 / 测试摘要快照，随报告一并导出
@property (nonatomic, strong) NSDictionary *environment;
@property (nonatomic, strong) NSDictionary *injector;
@property (nonatomic, strong) NSDictionary *helperTrust;
@property (nonatomic, strong) NSDictionary *securityGate;
@property (nonatomic, strong) NSDictionary *testSummary;

/// 记录一条指定类型的安全事件。
- (void)recordEventType:(FKSecurityEventType)type
                 target:(NSString *)target
                 result:(NSString *)result
                 reason:(NSString *)reason
               evidence:(NSDictionary *)evidence;

/// 生成当前安全报告。
- (FKSecurityReport *)securityReport;
/// 导出安全报告 JSON。
- (NSDictionary *)JSONDictionary;

@end
