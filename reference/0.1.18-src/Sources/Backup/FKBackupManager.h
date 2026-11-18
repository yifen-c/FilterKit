#import <Foundation/Foundation.h>
#import "FKOperationModels.h"
#import "FKBackupResult.h"
#import "FKBackupOperation.h"

@class FKScanReport;
@class FKAuditManager;

NS_ASSUME_NONNULL_BEGIN

/// 备份校验错误域
extern NSErrorDomain const FKBackupManagerErrorDomain;

/// 备份任务完成（成功 / 失败 / 取消）后发送；备份列表据此自动刷新。
FOUNDATION_EXPORT NSNotificationName const FKBackupDidFinishNotification;
/// 备份任务进度更新后发送；备份列表据此刷新行内进度。
FOUNDATION_EXPORT NSNotificationName const FKBackupProgressNotification;
/// 通知携带的插件 ID 键
FOUNDATION_EXPORT NSString *const FKBackupNotificationPluginIDKey;
/// 通知携带的备份 ID 键
FOUNDATION_EXPORT NSString *const FKBackupNotificationBackupIDKey;
/// 通知携带的状态键（completed / failed / cancelled）
FOUNDATION_EXPORT NSString *const FKBackupNotificationStatusKey;
/// 进度通知携带的进度值键（0.0 ~ 1.0）
FOUNDATION_EXPORT NSString *const FKBackupNotificationProgressKey;
/// 进度通知携带的当前文件名键
FOUNDATION_EXPORT NSString *const FKBackupNotificationCurrentFileKey;

typedef NS_ENUM(NSInteger, FKBackupManagerErrorCode) {
    FKBackupErrorInvalidJSON = 1,     /// 文件不是有效 JSON
    FKBackupErrorMissingManifest,     /// 缺少 manifest
    FKBackupErrorChecksumMismatch,    /// 分块 SHA-256 摘要不一致
    FKBackupErrorIncompatible,         /// 版本/结构不兼容
    FKBackupErrorCancelled            /// 备份任务被取消，半成品已清理
};

/// 备份管理器：仅生成、导出与校验备份数据；不恢复、不覆盖任何越狱环境文件。
@interface FKBackupManager : NSObject

/// 操作审计管理器（弱引用，避免循环持有）；备份成功 / 失败 / 取消回写历史。
@property (nonatomic, weak, nullable) FKAuditManager *auditManager;

- (instancetype)initWithReport:(nullable FKScanReport *)report;

/// 构建内存中的备份字典（manifest / apps / plugins / packages / filters / diagnostics）
- (NSDictionary *)createPluginBackup;

/// 将备份字典写入指定 URL（原子写入，失败不留部分文件）
- (BOOL)exportBackupToURL:(NSURL *)url error:(NSError *_Nullable *_Nullable)error;

/// 校验指定备份文件：解析 JSON、核对 manifest 与分块 SHA-256，兼容旧版报告；解析失败返回 nil
- (nullable NSDictionary *)validateBackupAtURL:(NSURL *)url error:(NSError *_Nullable *_Nullable)error;

/// 操作前备份：记录原始配置引用、修改前状态与完整性快照，返回备份 ID；参数无效返回 nil。不复制文件到原插件目录。
- (nullable NSString *)createOperationBackupForRequest:(FKOperationRequest *)request;

/// 按备份 ID 取操作备份记录；不存在返回 nil。
- (nullable NSDictionary *)operationBackupWithID:(NSString *)backupID;

/// 恢复前校验：备份完整性、目标归属与冲突检测；存在冲突时拒绝自动覆盖。
- (NSDictionary *)validateOperationBackup:(NSString *)backupID error:(NSError *_Nullable *_Nullable)error;

#pragma mark - 0.1.2 真实文件备份（仅写 App 沙盒）

/// 备份插件直接关联的 dylib 与 Filter plist 到受保护沙盒目录，计算 MD5/SHA-256 并重读校验。
/// 只读取越狱文件、只写入 App 沙盒；不覆盖旧备份，不恢复、不修改任何系统文件。失败返回 nil。
- (nullable NSDictionary *)backupPlugin:(NSString *)pluginID error:(NSError *_Nullable *_Nullable)error;

/// 全部已完成备份记录（按备份时间倒序）。
- (NSArray<NSDictionary *> *)allBackups;

/// 当前进行中的备份结果（尚未归档），按入队顺序返回；无进行中任务时为空数组。
- (NSArray<FKBackupResult *> *)activeBackupResults;

#pragma mark - 内部任务状态登记（供异步备份任务回调使用）

/// 登记一个进行中的备份结果。
- (void)registerActiveResult:(FKBackupResult *)result;
/// 更新进行中结果并发送进度通知。
- (void)updateActiveResult:(FKBackupResult *)result;
/// 任务结束后移除对应进行中结果。
- (void)removeActiveResultForPluginID:(NSString *)pluginID;

/// 按备份 ID 取备份记录；不存在返回 nil。
- (nullable NSDictionary *)backupWithID:(NSString *)backupID;

/// 备份结束后回写操作历史（成功 / 失败 / 取消）；审计管理器缺失时静默跳过。
- (void)recordBackupAuditWithResult:(FKBackupResult *)result error:(nullable NSError *)error;

/// 备份在沙盒内的目录路径；不存在返回 nil。
- (nullable NSString *)backupDirectoryForID:(NSString *)backupID;

#pragma mark - 0.1.3 异步备份

/// 异步备份：后台线程执行复制与哈希，进度/完成回调派发回主线程。
/// 仍只写 App 沙盒，不覆盖旧备份、不恢复或修改系统文件。
- (void)backupPluginAsync:(NSString *)pluginID
                  progress:(nullable FKBackupProgressHandler)progress
                completion:(nullable FKBackupCompletionHandler)completion;

/// 内部底层流程：供异步任务复用，逐文件回调进度；cancelCheck 返回 YES 时中止并清理半成品目录。
- (nullable NSDictionary *)runBackupForPluginID:(NSString *)pluginID
                                        progress:(nullable void (^)(double progress, NSString *_Nullable currentFile))progress
                                      cancelCheck:(nullable BOOL (^)(void))cancelCheck
                                            error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
