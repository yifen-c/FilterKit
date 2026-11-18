#import <Foundation/Foundation.h>
#import "FKBackupResult.h"

@class FKBackupManager;

NS_ASSUME_NONNULL_BEGIN

/// 备份进度回调；result 携带当前状态、进度与正在处理的文件。
typedef void (^FKBackupProgressHandler)(FKBackupResult *result);
/// 备份完成回调；error 为空表示成功。
typedef void (^FKBackupCompletionHandler)(FKBackupResult *result, NSError *_Nullable error);

/// 异步文件备份任务：在后台队列执行收集、复制、哈希、校验与清单提交。
/// 进度与完成回调均派发回主线程；取消只清理未提交的临时数据，不影响历史备份。
@interface FKBackupOperation : NSOperation

/// 设计为不可变入参，初始化后不应修改。
- (instancetype)initWithManager:(FKBackupManager *)manager
                        pluginID:(NSString *)pluginID
                        progress:(nullable FKBackupProgressHandler)progress
                      completion:(nullable FKBackupCompletionHandler)completion;

@end

NS_ASSUME_NONNULL_END
