#import "FKAuditManager.h"

/// 持久化记录格式版本；字段结构调整时递增，旧数据按低版本兼容读取。
static const NSUInteger FKAuditSchemaVersion = 3;

@interface FKAuditManager ()
@property (nonatomic, strong) NSMutableArray<FKOperationRecord *> *mutableRecords;
@property (nonatomic, strong) NSMutableArray<FKHelperIPCAuditEvent *> *mutableHelperIPCAuditEvents;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *lastPersistError;
@property (nonatomic, copy) NSDate *lastPersistedAt;
@property (nonatomic, assign) BOOL corruptedFileIsolated;
@property (nonatomic, strong) NSURL *auditFileURL;
@property (nonatomic, strong) NSURL *indexFileURL;
@property (nonatomic, strong) dispatch_queue_t persistQueue;
@end

@implementation FKAuditManager

- (instancetype)init {
    if ((self = [super init])) {
        _mutableRecords = [NSMutableArray array];
        _mutableHelperIPCAuditEvents = [NSMutableArray array];
        _lock = [NSLock new];
        _schemaVersion = FKAuditSchemaVersion;
        _persistQueue = dispatch_queue_create("com.filterkit.audit.persist", DISPATCH_QUEUE_SERIAL);
        [self resolvePersistenceURLs];
        [self loadPersistedRecords];
    }
    return self;
}

#pragma mark - 持久化路径与加载

/// 定位沙盒内 Audit 目录；仅使用 App 容器，不触碰越狱系统目录。
- (void)resolvePersistenceURLs {
    NSURL *appSupport = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                 inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [appSupport URLByAppendingPathComponent:@"FilterKit/Audit" isDirectory:YES];
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) self.lastPersistError = error.localizedDescription;
    self.auditFileURL = [dir URLByAppendingPathComponent:@"audit.json"];
    self.indexFileURL = [dir URLByAppendingPathComponent:@"audit-index.json"];
}

/// 启动加载历史；文件损坏时隔离原文件，不覆盖、不丢弃，内存从空记录开始。
- (void)loadPersistedRecords {
    NSData *data = [NSData dataWithContentsOfURL:self.auditFileURL];
    if (data.length == 0) return;

    NSError *parseError = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    NSArray *rawRecords = [payload isKindOfClass:NSDictionary.class] ? payload[@"records"] : nil;

    if (parseError || ![rawRecords isKindOfClass:NSArray.class]) {
        [self isolateCorruptedFile:self.auditFileURL reason:parseError.localizedDescription ?: @"记录结构非法"];
        return;
    }

    NSMutableArray<FKOperationRecord *> *loaded = [NSMutableArray array];
    for (id item in rawRecords) {
        FKOperationRecord *record = [FKOperationRecord recordFromDictionary:item];
        if (record) [loaded addObject:record];
    }
    // v2 文件没有 helper_ipc_events；按空数组迁移读取，不影响旧操作历史。
    NSMutableArray<FKHelperIPCAuditEvent *> *loadedIPC = [NSMutableArray array];
    NSArray *rawIPCEvents = [payload[@"helper_ipc_events"] isKindOfClass:NSArray.class] ? payload[@"helper_ipc_events"] : @[];
    for (id item in rawIPCEvents) {
        FKHelperIPCAuditEvent *event = [FKHelperIPCAuditEvent eventFromDictionary:item];
        if (event) [loadedIPC addObject:event];
    }
    [self.lock lock];
    [self.mutableRecords addObjectsFromArray:loaded];
    [self.mutableHelperIPCAuditEvents addObjectsFromArray:loadedIPC];
    [self.lock unlock];
}

/// 把损坏的历史文件改名隔离，保留现场供事后排查；不删除、不覆盖。
- (void)isolateCorruptedFile:(NSURL *)fileURL reason:(NSString *)reason {
    self.corruptedFileIsolated = YES;
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    NSString *stamp = [[formatter stringFromDate:[NSDate date]] stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    NSURL *backup = [[fileURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:
                     [NSString stringWithFormat:@"audit.corrupted-%@.json", stamp]];
    NSError *error = nil;
    [[NSFileManager defaultManager] moveItemAtURL:fileURL toURL:backup error:&error];
    self.lastPersistError = [NSString stringWithFormat:@"历史记录损坏已隔离：%@", reason ?: @"结构非法"];
}

#pragma mark - 记录追加

- (void)appendRecord:(FKOperationRecord *)record {
    if (![record isKindOfClass:FKOperationRecord.class]) return;
    [self.lock lock];
    [self.mutableRecords addObject:record];
    [self.lock unlock];
    [self persistAsync];
}

- (void)appendHelperIPCAuditEvent:(FKHelperIPCAuditEvent *)event {
    if (![event isKindOfClass:FKHelperIPCAuditEvent.class]) return;
    [self.lock lock];
    [self.mutableHelperIPCAuditEvents addObject:event];
    [self.lock unlock];
    [self persistAsync];
}

- (NSArray<FKHelperIPCAuditEvent *> *)helperIPCAuditEvents {
    [self.lock lock];
    NSArray<FKHelperIPCAuditEvent *> *sorted = [self.mutableHelperIPCAuditEvents sortedArrayUsingComparator:^NSComparisonResult(FKHelperIPCAuditEvent *a, FKHelperIPCAuditEvent *b) {
        return [a.timestamp compare:b.timestamp];
    }];
    [self.lock unlock];
    return sorted;
}

- (NSArray<FKOperationRecord *> *)records {
    [self.lock lock];
    NSArray<FKOperationRecord *> *sorted = [self.mutableRecords sortedArrayUsingComparator:^NSComparisonResult(FKOperationRecord *a, FKOperationRecord *b) {
        NSDate *ta = a.timestamp ?: [NSDate date];
        NSDate *tb = b.timestamp ?: [NSDate date];
        return [ta compare:tb];
    }];
    [self.lock unlock];
    return sorted;
}

- (NSArray<FKOperationRecord *> *)recordsForPluginID:(NSString *)pluginID {
    if (!pluginID.length) return self.records;
    return [self.records filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pluginID == %@", pluginID]];
}

- (NSArray<FKOperationRecord *> *)recordsForOperation:(NSString *)operation {
    if (!operation.length) return self.records;
    return [self.records filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"operation == %@", operation]];
}

- (NSArray<FKOperationRecord *> *)recordsForResult:(NSString *)result {
    if (!result.length) return self.records;
    return [self.records filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"result == %@", result]];
}

- (NSArray<FKOperationRecord *> *)recordsWithRollback {
    NSSet<NSString *> *rollbackCodes = [NSSet setWithArray:@[@"rolled_back", @"rollback_failed", @"recovery_required"]];
    NSMutableArray<FKOperationRecord *> *result = [NSMutableArray array];
    for (FKOperationRecord *record in self.records) {
        if (record.rollbackResult.length && [rollbackCodes containsObject:record.rollbackResult]) {
            [result addObject:record];
        }
    }
    return result.copy;
}

- (NSArray<FKOperationRecord *> *)recordsForOperation:(nullable NSString *)operation result:(nullable NSString *)result {
    NSPredicate *predicate = nil;
    if (operation.length && result.length) {
        predicate = [NSPredicate predicateWithFormat:@"operation == %@ AND result == %@", operation, result];
    } else if (operation.length) {
        predicate = [NSPredicate predicateWithFormat:@"operation == %@", operation];
    } else if (result.length) {
        predicate = [NSPredicate predicateWithFormat:@"result == %@", result];
    }
    return predicate ? [self.records filteredArrayUsingPredicate:predicate] : self.records;
}

- (FKOperationRecord *)recordForID:(NSString *)operationID {
    if (!operationID.length) return nil;
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"operationID == %@", operationID];
    return [self.records filteredArrayUsingPredicate:pred].firstObject;
}

- (void)recordBackupWithPluginID:(NSString *)pluginID
                         backupID:(NSString *)backupID
                        succeeded:(BOOL)succeeded
                           reason:(NSString *)reason
                     helperStatus:(NSString *)helperStatus {
    FKOperationRecord *record = [FKOperationRecord new];
    record.operationID = [NSUUID UUID].UUIDString;
    record.pluginID = pluginID ?: @"";
    record.operation = @"backup";
    record.result = succeeded ? @"success" : @"failed";
    record.verification = succeeded ? @"passed" : @"pending";
    record.backupID = backupID ?: @"";
    record.timestamp = [NSDate date];
    record.errorMessage = reason ?: @"";
    record.mode = @"preview_only";
    record.reasons = reason.length ? @[reason] : @[];
    record.helperStatus = helperStatus.length ? helperStatus : @"unverified";
    [self appendRecord:record];
}

#pragma mark - 持久化写入

/// 串行队列追加落盘；写入失败不回滚内存记录，仅记录错误供上层展示。
- (void)persistAsync {
    NSArray<FKOperationRecord *> *recordSnapshot = self.records;
    NSArray<FKHelperIPCAuditEvent *> *ipcSnapshot = self.helperIPCAuditEvents;
    dispatch_async(self.persistQueue, ^{
        [self persistRecords:recordSnapshot helperIPCAuditEvents:ipcSnapshot];
    });
}

- (void)persistRecords:(NSArray<FKOperationRecord *> *)records
  helperIPCAuditEvents:(NSArray<FKHelperIPCAuditEvent *> *)ipcEvents {
    NSMutableArray *items = [NSMutableArray array];
    NSMutableSet<NSString *> *plugins = [NSMutableSet set];
    NSMutableSet<NSString *> *operations = [NSMutableSet set];
    NSDate *latest = nil;
    for (FKOperationRecord *record in records) {
        [items addObject:record.JSONDictionary];
        if (record.pluginID.length) [plugins addObject:record.pluginID];
        if (record.operation.length) [operations addObject:record.operation];
        if (!latest || (record.timestamp && [record.timestamp compare:latest] == NSOrderedDescending)) latest = record.timestamp;
    }

    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    NSString *persistedAt = [formatter stringFromDate:[NSDate date]];
    NSMutableArray *ipcItems = [NSMutableArray arrayWithCapacity:ipcEvents.count];
    for (FKHelperIPCAuditEvent *event in ipcEvents) [ipcItems addObject:event.JSONDictionary];
    NSDictionary *payload = @{
        @"schema_version": @(FKAuditSchemaVersion),
        @"persisted_at": persistedAt,
        @"records": items.copy,
        @"helper_ipc_events": ipcItems.copy
    };
    NSDictionary *index = @{
        @"schema_version": @(FKAuditSchemaVersion),
        @"record_count": @(records.count),
        @"latest_timestamp": latest ? [formatter stringFromDate:latest] : @"",
        @"plugins": plugins.allObjects,
        @"operations": operations.allObjects
    };

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&error];
    if (data && [data writeToURL:self.auditFileURL options:NSDataWritingAtomic error:&error]) {
        NSData *indexData = [NSJSONSerialization dataWithJSONObject:index options:NSJSONWritingPrettyPrinted error:nil];
        if (indexData) [indexData writeToURL:self.indexFileURL options:NSDataWritingAtomic error:nil];
        self.lastPersistError = nil;
        self.lastPersistedAt = [NSDate date];
    } else {
        // 写盘失败：保留内存记录，错误上抛到状态摘要，不丢弃历史、不重试覆盖损坏文件。
        self.lastPersistError = error.localizedDescription ?: @"审计记录写入失败";
    }
}

#pragma mark - 导出与状态

- (NSDictionary *)JSONDictionary {
    NSMutableArray *items = [NSMutableArray array];
    for (FKOperationRecord *record in self.records) [items addObject:record.JSONDictionary];
    NSMutableArray *ipcItems = [NSMutableArray array];
    for (FKHelperIPCAuditEvent *event in self.helperIPCAuditEvents) [ipcItems addObject:event.JSONDictionary];
    return @{@"count": @(items.count),
             @"records": items.copy,
             @"helper_ipc_event_count": @(ipcItems.count),
             @"helper_ipc_events": ipcItems.copy};
}

- (NSDictionary *)persistenceStatus {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    return @{
        @"schema_version": @(FKAuditSchemaVersion),
        @"persisted": @(self.auditFileURL != nil),
        @"record_count": @(self.records.count),
        @"helper_ipc_event_count": @(self.helperIPCAuditEvents.count),
        @"last_persisted_at": self.lastPersistedAt ? [formatter stringFromDate:self.lastPersistedAt] : @"",
        @"corrupted_file_isolated": @(self.corruptedFileIsolated),
        @"last_persist_error": self.lastPersistError ?: @""
    };
}

@end
