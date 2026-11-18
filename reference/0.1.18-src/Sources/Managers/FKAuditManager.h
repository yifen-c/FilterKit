#import <Foundation/Foundation.h>
#import "FKOperationModels.h"
#import "FKHelperIPCAuditEvent.h"

NS_ASSUME_NONNULL_BEGIN

/// 操作审计：追加式记录启用/停用/校验/恢复等操作，普通操作不得覆盖历史记录。
/// 0.1.5 起在 App 沙盒内做 JSON 持久化：启动加载、追加原子写入；写入失败保留内存记录，
/// 损坏文件隔离不覆盖。持久化仅落在 App 沙盒，不写入越狱系统目录。
@interface FKAuditManager : NSObject

/// 当前持久化记录格式版本；调整字段结构时递增。
@property (nonatomic, assign, readonly) NSUInteger schemaVersion;
/// 最近一次持久化写入错误；无错误为 nil。
@property (nonatomic, copy, readonly, nullable) NSString *lastPersistError;

/// 追加一条操作记录。
- (void)appendRecord:(FKOperationRecord *)record;
/// 追加一条 Helper IPC 只读审计事件；与操作记录共用沙盒持久化文件。
- (void)appendHelperIPCAuditEvent:(FKHelperIPCAuditEvent *)event;
/// Helper IPC 事件历史（按时间先后排序）。
- (NSArray<FKHelperIPCAuditEvent *> *)helperIPCAuditEvents;
/// 全部记录（按时间先后排序）。
- (NSArray<FKOperationRecord *> *)records;
/// 按插件 ID 过滤。
- (NSArray<FKOperationRecord *> *)recordsForPluginID:(NSString *)pluginID;
/// 按操作类型文本过滤（enable / disable / validate / restore / backup）。
- (NSArray<FKOperationRecord *> *)recordsForOperation:(NSString *)operation;
/// 按操作结果过滤（success / failed / cancelled / unknown）。
- (NSArray<FKOperationRecord *> *)recordsForResult:(NSString *)result;
/// 存在真实回滚结论（已回滚 / 回滚失败 / 待人工恢复）的记录。
- (NSArray<FKOperationRecord *> *)recordsWithRollback;
/// 按操作类型与结果组合过滤；空串表示该维度不过滤。
- (NSArray<FKOperationRecord *> *)recordsForOperation:(nullable NSString *)operation result:(nullable NSString *)result;
/// 按操作 ID 查找单条记录；找不到返回 nil。
- (nullable FKOperationRecord *)recordForID:(NSString *)operationID;
/// 导出审计 JSON（追加历史随报告/备份一并导出）。
- (NSDictionary *)JSONDictionary;

/// 持久化状态摘要：记录数、schema 版本、最近写入时间、是否曾出现损坏隔离与写入错误。
- (NSDictionary *)persistenceStatus;

/// 记录一次只读文件备份（preview_only 模式；不代表真实启停）。
/// succeeded 为是否生成有效备份记录；reason 记录失败原因或为空。
- (void)recordBackupWithPluginID:(NSString *)pluginID
                         backupID:(NSString *)backupID
                        succeeded:(BOOL)succeeded
                           reason:(nullable NSString *)reason
                     helperStatus:(nullable NSString *)helperStatus;

@end

NS_ASSUME_NONNULL_END
