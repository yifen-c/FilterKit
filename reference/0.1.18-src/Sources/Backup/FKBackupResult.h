#import <Foundation/Foundation.h>

/// 备份任务状态。取消仅终止当前任务并清理未提交的临时数据，不破坏已完成的历史备份。
typedef NS_ENUM(NSInteger, FKBackupStatus) {
    FKBackupStatusPending = 0,   /// 已入队，尚未开始
    FKBackupStatusRunning,        /// 正在复制与哈希计算
    FKBackupStatusVerifying,      /// 已复制完成，正在重读校验与提交清单
    FKBackupStatusCompleted,      /// 备份完成且摘要校验通过
    FKBackupStatusFailed,         /// 备份失败，临时目录已清理
    FKBackupStatusCancelled       /// 任务被取消，未提交数据已清理
};

/// 一次文件备份的结果模型：承载进度、状态、统计与完成后的索引记录。
@interface FKBackupResult : NSObject

/// 当前任务状态
@property (nonatomic, assign) FKBackupStatus status;
/// 备份 ID；未完成或失败时为空
@property (nonatomic, copy) NSString *backupID;
/// 目标插件 ID
@property (nonatomic, copy) NSString *pluginID;
/// 已备份文件数
@property (nonatomic, assign) NSUInteger fileCount;
/// 已备份文件总字节数
@property (nonatomic, assign) unsigned long long totalSizeBytes;
/// 当前正在处理的文件名；无则为空
@property (nonatomic, copy) NSString *currentFile;
/// 总体进度 0.0 ~ 1.0
@property (nonatomic, assign) double progress;
/// MD5 是否已记录
@property (nonatomic, assign) BOOL md5Recorded;
/// 备份副本 SHA-256 重读是否通过
@property (nonatomic, assign) BOOL sha256Verified;
/// Manifest 是否已生成并提交
@property (nonatomic, assign) BOOL manifestGenerated;
/// 失败原因；成功为空
@property (nonatomic, strong) NSError *error;
/// 完成后写入 index.json 的索引记录；未完成时为 nil
@property (nonatomic, copy) NSDictionary *record;

/// 状态机器可读标识
+ (NSString *)codeForStatus:(FKBackupStatus)status;
/// 状态中文文案
+ (NSString *)textForStatus:(FKBackupStatus)status;
/// 序列化为报告/历史可用的字典
- (NSDictionary *)JSONDictionary;

@end
