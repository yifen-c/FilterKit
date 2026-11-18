#import "FKInjectionPreviewManager.h"

static const NSUInteger FKPreviewSchemaVersion = 1;

/// 把兼容性检查项的 key 归入预览五组之一。
static NSString *FKCheckGroupForKey(NSString *key) {
    if ([key isEqualToString:@"app"]) return @"App";
    if ([key hasPrefix:@"file"] || [key isEqualToString:@"filter"]) return @"Plugin";
    if ([key hasPrefix:@"macho"] || [key isEqualToString:@"architecture"] ||
        [key isEqualToString:@"install_name"] || [key isEqualToString:@"dependencies"]) return @"Mach-O";
    if ([key isEqualToString:@"injector"]) return @"Injector";
    return @"Unknown";
}

@interface FKInjectionPreviewManager ()
@property (nonatomic, strong) NSMutableArray<FKInjectionPreview *> *mutablePreviews;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *lastPersistError;
@property (nonatomic, strong) NSURL *previewsURL;
@property (nonatomic, strong) dispatch_queue_t persistQueue;
@end

@implementation FKInjectionPreviewManager

- (instancetype)init {
    if ((self = [super init])) {
        _mutablePreviews = [NSMutableArray array];
        _lock = [NSLock new];
        _schemaVersion = FKPreviewSchemaVersion;
        _persistQueue = dispatch_queue_create("com.filterkit.preview.persist", DISPATCH_QUEUE_SERIAL);
        [self resolvePersistenceURL];
        [self loadPersistedPreviews];
    }
    return self;
}

#pragma mark - 持久化

- (void)resolvePersistenceURL {
    NSURL *appSupport = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                 inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [appSupport URLByAppendingPathComponent:@"FilterKit/Previews" isDirectory:YES];
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) self.lastPersistError = error.localizedDescription;
    self.previewsURL = [dir URLByAppendingPathComponent:@"previews.json"];
}

- (void)loadPersistedPreviews {
    NSData *data = [NSData dataWithContentsOfURL:self.previewsURL];
    if (data.length == 0) return;
    NSError *parseError = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    NSArray *raw = [payload isKindOfClass:NSDictionary.class] ? payload[@"previews"] : nil;
    if (parseError || ![raw isKindOfClass:NSArray.class]) {
        [self isolateCorruptedFile:self.previewsURL reason:parseError.localizedDescription ?: @"预览记录结构非法"];
        return;
    }
    NSMutableArray<FKInjectionPreview *> *loaded = [NSMutableArray array];
    for (id item in raw) {
        FKInjectionPreview *preview = [FKInjectionPreview previewFromDictionary:item];
        if (preview) [loaded addObject:preview];
    }
    [self.lock lock];
    [self.mutablePreviews addObjectsFromArray:loaded];
    [self.lock unlock];
}

- (void)isolateCorruptedFile:(NSURL *)fileURL reason:(NSString *)reason {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    NSString *stamp = [[formatter stringFromDate:[NSDate date]] stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    NSString *base = fileURL.lastPathComponent.stringByDeletingPathExtension;
    NSURL *backup = [fileURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:
                     [NSString stringWithFormat:@"%@.corrupted-%@.json", base, stamp]];
    NSError *error = nil;
    [[NSFileManager defaultManager] moveItemAtURL:fileURL toURL:backup error:&error];
    self.lastPersistError = [NSString stringWithFormat:@"%@ 已隔离：%@", base, reason ?: @"结构非法"];
}

#pragma mark - 预览生成

- (FKInjectionPreview *)buildPreviewForApp:(FKAppModel *)app
                                     plugin:(FKPluginModel *)plugin
                                injectorType:(NSString *)injectorType
                             compatibility:(FKPluginCompatibility *)compatibility
                                 trustReport:(NSDictionary *)trustReport {
    FKInjectionPreview *preview = [FKInjectionPreview new];
    preview.previewID = [NSUUID UUID].UUIDString;
    preview.appBundleID = app.bundleID ?: @"";
    preview.pluginID = plugin.pluginID ?: @"";
    preview.dylibPath = plugin.dylibPath ?: @"";
    preview.injectorType = injectorType ?: @"";
    preview.createdAt = [NSDate date];
    preview.previewOnly = YES;
    preview.systemModified = NO;

    NSMutableArray<NSDictionary *> *checks = [NSMutableArray array];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];

    // 兼容性逐项检查归入对应分组。
    for (NSDictionary *check in compatibility.checks ?: @[]) {
        NSMutableDictionary *grouped = [check mutableCopy];
        grouped[@"group"] = FKCheckGroupForKey(check[@"key"] ?: @"");
        [checks addObject:grouped];
    }
    [warnings addObjectsFromArray:compatibility.warnings ?: @[]];
    [warnings addObjectsFromArray:compatibility.conflicts ?: @[]];

    // Security 组：Helper 信任快照与操作权限。0.1.6 不连接、不启动 Helper。
    NSDictionary *helper = [trustReport isKindOfClass:NSDictionary.class] ? trustReport : @{};
    NSString *helperState = [helper[@"state"] isKindOfClass:NSString.class] ? helper[@"state"] : @"unknown";
    NSString *helperText = [helper[@"state_text"] isKindOfClass:NSString.class] ? helper[@"state_text"] : @"未验证";
    BOOL helperTrusted = [helperState isEqualToString:@"trusted"];
    [checks addObject:@{
        @"group": @"Security", @"key": @"helper_trust",
        @"status": helperTrusted ? FKCheckStatusPass : FKCheckStatusWarn,
        @"detail": [NSString stringWithFormat:@"Helper：%@", helperText]
    }];
    [checks addObject:@{
        @"group": @"Security", @"key": @"ipc_connected",
        @"status": FKCheckStatusUnknown,
        @"detail": @"0.1.15 未建立真实 Helper IPC 连接"
    }];
    [checks addObject:@{
        @"group": @"Security", @"key": @"real_operation",
        @"status": FKCheckStatusFail,
        @"detail": @"真实启停 / 修改注入器配置 / 真实恢复在 0.1.15 一律禁止，仅生成预览"
    }];

    preview.checks = checks.copy;
    preview.warnings = warnings.copy;
    preview.result = [self previewResultForCompatibility:compatibility helperTrusted:helperTrusted];
    return preview;
}

/// 预览综合结论：不兼容 → 阻断；存在警告/存疑 → 带警告；否则可继续保存管理关系。
- (FKPreviewResult)previewResultForCompatibility:(FKPluginCompatibility *)compatibility helperTrusted:(BOOL)helperTrusted {
    (void)helperTrusted;
    if (compatibility.status == FKCompatibilityStatusIncompatible) return FKPreviewResultBlocked;
    if (compatibility.warnings.count > 0 || compatibility.conflicts.count > 0) return FKPreviewResultWarnings;
    return FKPreviewResultReady;
}

#pragma mark - 记录管理

- (void)savePreview:(FKInjectionPreview *)preview {
    if (![preview isKindOfClass:FKInjectionPreview.class]) return;
    preview.previewOnly = YES;
    preview.systemModified = NO;
    [self.lock lock];
    [self.mutablePreviews addObject:preview];
    [self.lock unlock];
    [self persistPreviews];
}

- (NSArray<FKInjectionPreview *> *)allPreviews {
    [self.lock lock];
    NSArray<FKInjectionPreview *> *sorted = [self.mutablePreviews sortedArrayUsingComparator:^NSComparisonResult(FKInjectionPreview *a, FKInjectionPreview *b) {
        NSDate *ta = a.createdAt ?: [NSDate date];
        NSDate *tb = b.createdAt ?: [NSDate date];
        return [tb compare:ta];
    }];
    [self.lock unlock];
    return sorted;
}

- (NSArray<FKInjectionPreview *> *)previewsForApp:(NSString *)appBundleID {
    if (!appBundleID.length) return @[];
    return [self.allPreviews filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"appBundleID == %@", appBundleID]];
}

- (NSArray<FKInjectionPreview *> *)previewsForPlugin:(NSString *)pluginID {
    if (!pluginID.length) return @[];
    return [self.allPreviews filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pluginID == %@", pluginID]];
}

#pragma mark - 持久化写入

- (void)persistPreviews {
    NSArray<FKInjectionPreview *> *snapshot = self.allPreviews;
    NSArray *items = [snapshot valueForKey:@"JSONDictionary"];
    NSDictionary *payload = @{@"schema_version": @(FKPreviewSchemaVersion), @"previews": items};
    dispatch_async(self.persistQueue, ^{
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&error];
        if (data && [data writeToURL:self.previewsURL options:NSDataWritingAtomic error:&error]) {
            self.lastPersistError = nil;
        } else {
            self.lastPersistError = error.localizedDescription ?: @"预览记录写入失败";
        }
    });
}

#pragma mark - 导出与状态

- (NSDictionary *)JSONDictionary {
    return @{@"count": @(self.allPreviews.count), @"previews": [self.allPreviews valueForKey:@"JSONDictionary"]};
}

- (NSDictionary *)persistenceStatus {
    return @{
        @"schema_version": @(FKPreviewSchemaVersion),
        @"preview_count": @(self.allPreviews.count),
        @"last_persist_error": self.lastPersistError ?: @""
    };
}

@end
