#import "FKBackupOperation.h"
#import "FKBackupManager.h"

@interface FKBackupOperation ()
@property (nonatomic, weak, nullable) FKBackupManager *manager;
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, copy, nullable) FKBackupProgressHandler progressHandler;
@property (nonatomic, copy, nullable) FKBackupCompletionHandler completionHandler;
@property (nonatomic, strong) FKBackupResult *result;
@end

@implementation FKBackupOperation

- (instancetype)initWithManager:(FKBackupManager *)manager
                        pluginID:(NSString *)pluginID
                        progress:(nullable FKBackupProgressHandler)progress
                      completion:(nullable FKBackupCompletionHandler)completion {
    if ((self = [super init])) {
        _manager = manager;
        _pluginID = [pluginID copy];
        _progressHandler = [progress copy];
        _completionHandler = [completion copy];
    }
    return self;
}

/// 在主线程执行回调；已在主线程时直接调用，避免多余派发。
static void FKDispatchMain(void (^_Nonnull block)(void)) {
    if (NSThread.isMainThread) { block(); }
    else { dispatch_async(dispatch_get_main_queue(), block); }
}

- (void)main {
    FKBackupResult *result = [FKBackupResult new];
    result.pluginID = self.pluginID ?: @"";
    result.status = FKBackupStatusRunning;
    self.result = result;
    [self.manager registerActiveResult:result];

    __weak typeof(self) weakSelf = self;
    // 逐文件进度回调：底层在后台线程调用，这里汇总到结果并切主线程通知 UI。
    void (^progress)(double, NSString *_Nullable) = ^(double progressValue, NSString *currentFile) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        result.progress = progressValue;
        result.currentFile = currentFile ?: @"";
        result.status = [currentFile isEqualToString:@"manifest.json"] ? FKBackupStatusVerifying : FKBackupStatusRunning;
        FKDispatchMain(^{
            [strongSelf.manager updateActiveResult:result];
            if (strongSelf.progressHandler) {
                strongSelf.progressHandler(result);
            }
        });
    };
    // 取消判定：读取 NSOperation 的取消标志，供底层在文件间隙中止并清理半成品。
    BOOL (^cancelCheck)(void) = ^BOOL { return weakSelf.isCancelled; };

    NSError *error = nil;
    NSDictionary *record = [self.manager runBackupForPluginID:self.pluginID
                                                      progress:progress
                                                    cancelCheck:cancelCheck
                                                          error:&error];
    if (self.isCancelled) {
        result.status = FKBackupStatusCancelled;
        result.error = error;
    } else if (record) {
        result.backupID = record[@"backup_id"] ?: @"";
        result.record = record;
        result.fileCount = [record[@"file_count"] unsignedIntegerValue];
        result.manifestGenerated = YES;
        result.sha256Verified = YES;
        // 汇总文件总大小与 MD5 记录情况。
        NSArray *files = [record[@"files"] isKindOfClass:NSArray.class] ? record[@"files"] : @[];
        unsigned long long totalSize = 0;
        BOOL md5Recorded = YES;
        for (NSDictionary *file in files) {
            totalSize += [file[@"size"] unsignedLongLongValue];
            if (![file[@"md5"] length]) md5Recorded = NO;
        }
        result.totalSizeBytes = totalSize;
        result.md5Recorded = md5Recorded;
        result.progress = 1.0;
        result.status = FKBackupStatusCompleted;
    } else {
        result.error = error;
        result.status = FKBackupStatusFailed;
    }

    NSString *statusCode = @"failed";
    if (result.status == FKBackupStatusCompleted) statusCode = @"completed";
    else if (result.status == FKBackupStatusCancelled) statusCode = @"cancelled";
    NSDictionary *userInfo = @{
        FKBackupNotificationPluginIDKey: result.pluginID ?: @"",
        FKBackupNotificationBackupIDKey: result.backupID ?: @"",
        FKBackupNotificationStatusKey: statusCode
    };

    FKDispatchMain(^{
        [weakSelf.manager removeActiveResultForPluginID:result.pluginID];
        [weakSelf.manager recordBackupAuditWithResult:result error:result.error];
        [NSNotificationCenter.defaultCenter postNotificationName:FKBackupDidFinishNotification object:nil userInfo:userInfo];
        if (weakSelf.completionHandler) {
            weakSelf.completionHandler(result, result.error);
        }
    });
}

@end
