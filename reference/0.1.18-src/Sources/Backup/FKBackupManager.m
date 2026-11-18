#import "FKBackupManager.h"
#import "FKScanner.h"
#import "FKPluginManager.h"
#import "FKAppManager.h"
#import "FKBackupManifest.h"
#import "FKBackupValidator.h"
#import "FKFileHasher.h"
#import "FKConfigurationBackup.h"
#import "FKAuditManager.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>

NSErrorDomain const FKBackupManagerErrorDomain = @"com.filterkit.backup";

NSNotificationName const FKBackupDidFinishNotification = @"FKBackupDidFinishNotification";
NSNotificationName const FKBackupProgressNotification = @"FKBackupProgressNotification";
NSString *const FKBackupNotificationPluginIDKey = @"plugin_id";
NSString *const FKBackupNotificationBackupIDKey = @"backup_id";
NSString *const FKBackupNotificationStatusKey = @"status";
NSString *const FKBackupNotificationProgressKey = @"progress";
NSString *const FKBackupNotificationCurrentFileKey = @"current_file";

/// 计算数据的 SHA-256 十六进制摘要（用于备份分块完整性校验）。
static NSString *FKSHA256Hex(NSData *data) {
    if (!data.length) return @"";
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex.copy;
}

/// 将对象序列化为紧凑 JSON 数据，失败返回 nil。
static NSData *FKCompactJSON(id object) {
    if (!object) return nil;
    return [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
}

static NSString *FKSafeTextManifest(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

@interface FKBackupManager ()
@property (nonatomic, strong) FKScanReport *report;
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKAppManager *appManager;
/// 操作前备份记录（内存），按备份 ID 索引。
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *operationBackups;
/// 真实文件备份记录缓存，按备份 ID 索引。
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *fileBackups;
/// 进行中的备份结果，按插件 ID 索引；仅用于列表行内进度展示，不写入历史索引。
@property (nonatomic, strong) NSMutableDictionary<NSString *, FKBackupResult *> *activeResults;
/// 保护活跃结果字典的并发访问。
@property (nonatomic, strong) NSLock *activeLock;
/// 是否已从 index.json 加载历史备份。
@property (nonatomic, assign) BOOL backupsLoaded;
/// 异步备份串行队列：避免多个备份任务并发复制与写索引。
@property (nonatomic, strong) NSOperationQueue *backupQueue;
@end

@implementation FKBackupManager

- (instancetype)initWithReport:(FKScanReport *)report {
    if ((self = [super init])) {
        _report = report;
        _pluginManager = [[FKPluginManager alloc] initWithPlugins:report.plugins ?: @[]];
        _appManager = [[FKAppManager alloc] initWithApps:report.apps ?: @[] plugins:_pluginManager.allPlugins];
        _operationBackups = [NSMutableDictionary dictionary];
        _fileBackups = [NSMutableDictionary dictionary];
        _activeResults = [NSMutableDictionary dictionary];
        _activeLock = [NSLock new];
        _backupQueue = [NSOperationQueue new];
        _backupQueue.maxConcurrentOperationCount = 1;
        _backupQueue.name = @"com.filterkit.backup";
    }
    return self;
}

#pragma mark - 分块组装

- (NSArray<NSDictionary *> *)appBackupJSON {
    return [self.appManager.allApps valueForKey:@"JSONDictionary"];
}

- (NSArray<NSDictionary *> *)pluginBackupJSON {
    return [self.pluginManager.allPlugins valueForKey:@"JSONDictionary"];
}

- (NSArray<NSDictionary *> *)filterBackupJSON {
    NSMutableArray *filters = [NSMutableArray array];
    for (FKPluginModel *plugin in self.pluginManager.allPlugins) {
        [filters addObject:@{@"plugin_id": plugin.pluginID ?: @"", @"filter": plugin.filter.JSONDictionary ?: @{}}];
    }
    return filters.copy;
}

- (NSArray<NSDictionary *> *)packageBackupJSON {
    NSDictionary *fs = [self.report.filesystem isKindOfClass:NSDictionary.class] ? self.report.filesystem : @{};
    NSArray *packages = [fs[@"dpkg_packages"] isKindOfClass:NSArray.class] ? fs[@"dpkg_packages"] : @[];
    return packages;
}

- (NSDictionary *)diagnosticsBackupJSON {
    NSDictionary *fs = [self.report.filesystem isKindOfClass:NSDictionary.class] ? self.report.filesystem : @{};
    NSDictionary *env = [self.report.environment isKindOfClass:NSDictionary.class] ? self.report.environment : @{};
    NSDictionary *dpkgAnalysis = [fs[@"dpkg_analysis"] isKindOfClass:NSDictionary.class] ? fs[@"dpkg_analysis"] : @{};
    NSDictionary *integrity = [dpkgAnalysis[@"integrity"] isKindOfClass:NSDictionary.class] ? dpkgAnalysis[@"integrity"] : @{};
    NSDictionary *checksum = [integrity[@"checksum_analysis"] isKindOfClass:NSDictionary.class] ? integrity[@"checksum_analysis"] : @{};

    NSMutableArray *tests = [NSMutableArray array];
    NSUInteger passed = 0, failed = 0, unknown = 0;
    for (FKTestResult *result in self.report.tests ?: @[]) {
        [tests addObject:result.JSONDictionary];
        if (result.state == FKTestStatePassed) passed++;
        else if (result.state == FKTestStateFailed) failed++;
        else unknown++;
    }
    return @{
        @"summary": @{@"total": @(self.report.tests.count), @"passed": @(passed),
                      @"failed": @(failed), @"unknown": @(unknown)},
        @"tests": tests.copy,
        @"checksum_analysis": checksum,
        @"injector": env[@"injector"] ?: @{}
    };
}

- (NSDictionary *)createPluginBackup {
    NSArray *apps = [self appBackupJSON];
    NSArray *plugins = [self pluginBackupJSON];
    NSArray *packages = [self packageBackupJSON];
    NSArray *filters = [self filterBackupJSON];
    NSDictionary *diagnostics = [self diagnosticsBackupJSON];

    // 各分块先序列化再算摘要，保证 manifest 记录的是实际落盘内容的哈希。
    NSDictionary *blocks = @{@"apps": apps, @"plugins": plugins, @"packages": packages,
                             @"filters": filters, @"diagnostics": diagnostics};
    NSMutableDictionary<NSString *, NSString *> *blockHashes = [NSMutableDictionary dictionary];
    for (NSString *key in blocks) {
        blockHashes[key] = FKSHA256Hex(FKCompactJSON(blocks[key]));
    }

    NSDictionary *env = [self.report.environment isKindOfClass:NSDictionary.class] ? self.report.environment : @{};
    NSDictionary *manifest = @{
        @"backup_format": @"filterkit-backup",
        @"format_version": @1,
        @"tool_version": self.report.JSONDictionary[@"version"] ?: @"unknown",
        @"generated_at": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date],
        @"device": @{
            @"ios_version": env[@"ios_version"] ?: @"unknown",
            @"architecture": env[@"architecture"] ?: @"unknown",
            @"jailbreak": env[@"jailbreak"] ?: @"unknown"
        },
        @"counts": @{@"apps": @(apps.count), @"plugins": @(plugins.count), @"packages": @(packages.count)},
        @"block_sha256": blockHashes.copy
    };

    return @{@"manifest": manifest, @"apps": apps, @"plugins": plugins,
             @"packages": packages, @"filters": filters, @"diagnostics": diagnostics};
}

#pragma mark - 导出

- (BOOL)exportBackupToURL:(NSURL *)url error:(NSError **)error {
    NSDictionary *backup = [self createPluginBackup];
    NSData *data = [NSJSONSerialization dataWithJSONObject:backup options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return NO;
    // 原子写入：中途失败不会留下残缺文件。
    return [data writeToFile:url.path options:NSDataWritingAtomic error:error];
}

#pragma mark - 校验（只读）

- (NSDictionary *)validateBackupAtURL:(NSURL *)url error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) return nil;

    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![parsed isKindOfClass:NSDictionary.class]) {
        if (error) *error = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorInvalidJSON
                                            userInfo:@{NSLocalizedDescriptionKey: @"文件不是有效的 JSON 备份"}];
        return nil;
    }
    NSDictionary *backup = (NSDictionary *)parsed;
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];

    NSDictionary *manifest = [backup[@"manifest"] isKindOfClass:NSDictionary.class] ? backup[@"manifest"] : nil;
    if (!manifest) {
        // 兼容旧版扫描报告：无 manifest 但含 tests/plugins，标记为 legacy，不视为损坏。
        if (backup[@"tests"] || backup[@"plugins"]) {
            [warnings addObject:@"旧版扫描报告，无备份摘要，无法做分块完整性校验"];
            return @{@"valid": @YES, @"format": @"legacy-report",
                     @"version": backup[@"version"] ?: @"unknown", @"errors": errors.copy, @"warnings": warnings.copy};
        }
        if (error) *error = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorMissingManifest
                                            userInfo:@{NSLocalizedDescriptionKey: @"备份缺少 manifest 段"}];
        return nil;
    }

    NSString *format = FKSafeTextManifest(manifest[@"backup_format"]);
    if (![format isEqualToString:@"filterkit-backup"]) {
        [errors addObject:[NSString stringWithFormat:@"备份格式不匹配：%@", format]];
    }

    // 重算各分块摘要并与 manifest 比对。
    NSDictionary<NSString *, NSString *> *expected = [manifest[@"block_sha256"] isKindOfClass:NSDictionary.class] ? manifest[@"block_sha256"] : @{};
    NSArray<NSString *> *keys = @[@"apps", @"plugins", @"packages", @"filters", @"diagnostics"];
    for (NSString *key in keys) {
        NSString *expectedHash = expected[key];
        if (!expectedHash.length) continue;
        NSString *actualHash = FKSHA256Hex(FKCompactJSON(backup[key]));
        if (![actualHash isEqualToString:expectedHash]) {
            [errors addObject:[NSString stringWithFormat:@"分块 %@ 摘要不一致", key]];
        }
    }

    BOOL valid = errors.count == 0;
    if (!valid && error) {
        *error = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorChecksumMismatch
                                 userInfo:@{NSLocalizedDescriptionKey: [errors componentsJoinedByString:@"; "]}];
    }
    return @{@"valid": @(valid), @"format": @"filterkit-backup",
             @"version": manifest[@"tool_version"] ?: @"unknown",
             @"entries": manifest[@"counts"] ?: @{}, @"errors": errors.copy, @"warnings": warnings.copy};
}

#pragma mark - 操作前备份与恢复校验

/// 操作备份时间格式化。
static NSString *FKBackupTimestamp(NSDate *date) {
    if (!date) return @"";
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter stringFromDate:date];
}

- (NSString *)createOperationBackupForRequest:(FKOperationRequest *)request {
    if (![request isKindOfClass:FKOperationRequest.class] || request.pluginID.length == 0) return nil;
    FKPluginModel *model = [self.pluginManager pluginForID:request.pluginID];
    NSString *backupID = request.requestID.length ? request.requestID : [NSUUID UUID].UUIDString;

    NSDictionary *originalConfig = @{
        @"filter_path": model.filterPath ?: @"",
        @"dylib_path": model.dylibPath ?: @"",
        @"bundles": model.filter.bundles ?: @[],
        @"executables": model.filter.executables ?: @[],
        @"classes": model.filter.classes ?: @[]
    };
    NSDictionary *integrity = @{
        @"file_status": model.fileStatus ?: @"unknown",
        @"package_id": model.packageID ?: @"",
        @"association_type": model.associationType ?: @"unknown",
        @"original_sha256": @"",  // 真实受控操作前由校验流程补算文件摘要
        @"note": @"只读快照；未复制原始文件到原插件目录"
    };
    // 配置快照：仅记录原始配置上下文与只读摘要，不复制、不覆盖原配置文件；与插件文件备份相互独立。
    FKConfigurationBackup *configSnapshot = [FKConfigurationBackup backupWithPluginID:request.pluginID
                                                                          injectorType:nil
                                                                      targetAppBundleID:request.appBundleID
                                                                            operationID:request.requestID
                                                                 originalConfiguration:originalConfig];
    NSDictionary *record = @{
        @"backup_id": backupID,
        @"request_id": request.requestID ?: @"",
        @"plugin_id": request.pluginID,
        @"operation": [FKOperationRequest operationText:request.operation],
        @"created_at": FKBackupTimestamp(request.createdAt),
        @"original_state": @{
            @"integrity_status": model.integrityStatus ?: @"未知",
            @"association_type": model.associationType ?: @"unknown"
        },
        @"original_config": originalConfig,
        @"configuration_snapshot": configSnapshot.JSONDictionary,
        @"integrity": integrity
    };
    self.operationBackups[backupID] = record;
    return backupID;
}

- (NSDictionary *)operationBackupWithID:(NSString *)backupID {
    return backupID.length ? self.operationBackups[backupID] : nil;
}

- (NSDictionary *)validateOperationBackup:(NSString *)backupID error:(NSError **)error {
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];
    NSMutableArray<NSString *> *conflicts = [NSMutableArray array];
    NSDictionary *record = backupID.length ? self.operationBackups[backupID] : nil;

    if (!record) {
        if (error) *error = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorMissingManifest
            userInfo:@{NSLocalizedDescriptionKey: @"未找到对应操作备份"}];
        return @{@"valid": @NO, @"reasons": @[@"备份记录不存在"], @"conflicts": conflicts.copy};
    }

    // 备份完整性：必备段不得缺失。
    for (NSString *key in @[@"backup_id", @"plugin_id", @"original_config", @"integrity"]) {
        if (!record[key]) [reasons addObject:[NSString stringWithFormat:@"备份缺少 %@ 段", key]];
    }

    // 冲突检测：当前扫描结果与备份时的路径、包归属比对；不一致则拒绝自动覆盖。
    FKPluginModel *model = [self.pluginManager pluginForID:record[@"plugin_id"]];
    NSDictionary *originalConfig = [record[@"original_config"] isKindOfClass:NSDictionary.class] ? record[@"original_config"] : @{};
    NSDictionary *originalIntegrity = [record[@"integrity"] isKindOfClass:NSDictionary.class] ? record[@"integrity"] : @{};
    if (!model) {
        [conflicts addObject:@"备份后插件已不在当前扫描结果中，需人工确认"];
    } else {
        if (![model.dylibPath isEqualToString:originalConfig[@"dylib_path"]]) {
            [conflicts addObject:@"dylib 路径与备份时不一致"];
        }
        if (![model.packageID isEqualToString:originalIntegrity[@"package_id"]]) {
            [conflicts addObject:@"软件包归属与备份时不一致"];
        }
    }

    BOOL valid = reasons.count == 0 && conflicts.count == 0;
    if (!valid && error) {
        NSArray<NSString *> *merged = [reasons arrayByAddingObjectsFromArray:conflicts];
        NSString *detail = [merged componentsJoinedByString:@"; "];
        *error = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorChecksumMismatch
            userInfo:@{NSLocalizedDescriptionKey: detail}];
    }
    return @{@"valid": @(valid), @"reasons": reasons.copy, @"conflicts": conflicts.copy};
}

#pragma mark - 真实文件备份（仅写入 App 沙盒）

/// 备份根目录：App 受保护数据目录下，不写入越狱插件目录。
- (NSString *)backupsDir {
    NSString *appSupport = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *dir = [appSupport stringByAppendingPathComponent:@"FilterKit/Backups"];
    if (![NSFileManager.defaultManager fileExistsAtPath:dir]) {
        [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

/// 将插件 ID 规范化为安全目录名。
- (NSString *)safeNameForText:(NSString *)text {
    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    NSString *safe = [[text componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"_"];
    return safe.length ? safe : @"plugin";
}

/// 备份文件粗类型：优先 Mach-O 头 magic，其次 plist 扩展名。
static NSString *FKBackupFileType(NSString *path) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (handle) {
        NSData *head = [handle readDataOfLength:4];
        [handle closeFile];
        if (head.length >= 4) {
            const unsigned char *h = head.bytes;
            uint32_t magic = ((uint32_t)h[0] << 24) | ((uint32_t)h[1] << 16) | ((uint32_t)h[2] << 8) | h[3];
            if (magic == 0xfeedface || magic == 0xfeedfacf || magic == 0xcefaedfe || magic == 0xcffaedfe ||
                magic == 0xcafebabe || magic == 0xbebafeca || magic == 0xcafebabf || magic == 0xbfbafeca) {
                return @"mach_o";
            }
        }
    }
    if ([path.pathExtension.lowercaseString isEqualToString:@"plist"]) return @"configuration";
    if (path.pathExtension.length == 0) return @"unknown";
    return @"text";
}

/// 收集插件直接关联、且存在可读的 dylib 与 Filter plist 路径。
- (NSArray<NSString *> *)backupablePathsForModel:(FKPluginModel *)model {
    NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *path in @[model.dylibPath ?: @"", model.filterPath ?: @""]) {
        if (path.length == 0) continue;
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:path isDirectory:&isDir] && !isDir) [paths addObject:path];
    }
    return paths.array;
}

- (NSDictionary *)backupPlugin:(NSString *)pluginID error:(NSError **)error {
    return [self runBackupForPluginID:pluginID progress:nil cancelCheck:nil error:error];
}

/// 备份结束后回写操作历史；Helper 未验证前恒记 unverified。审计管理器缺失时静默跳过记录。
- (void)recordBackupAuditWithResult:(FKBackupResult *)result error:(NSError *)error {
    if (!self.auditManager || ![result isKindOfClass:FKBackupResult.class]) return;
    BOOL succeeded = result.status == FKBackupStatusCompleted;
    NSString *reason = succeeded ? @"" : (error.localizedDescription ?: result.error.localizedDescription ?: @"备份未完成");
    [self.auditManager recordBackupWithPluginID:result.pluginID backupID:result.backupID succeeded:succeeded reason:reason helperStatus:@"unverified"];
}

- (void)backupPluginAsync:(NSString *)pluginID
                  progress:(FKBackupProgressHandler)progress
                completion:(FKBackupCompletionHandler)completion {
    FKBackupOperation *operation = [[FKBackupOperation alloc] initWithManager:self
                                                                      pluginID:pluginID
                                                                      progress:progress
                                                                    completion:completion];
    [self.backupQueue addOperation:operation];
}

- (NSDictionary *)runBackupForPluginID:(NSString *)pluginID
                                progress:(void (^)(double progress, NSString *_Nullable currentFile))progress
                              cancelCheck:(BOOL (^)(void))cancelCheck
                                    error:(NSError **)error {
    FKPluginModel *model = pluginID.length ? [self.pluginManager pluginForID:pluginID] : nil;
    if (!model) {
        if (error) *error = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorMissingManifest
                                          userInfo:@{NSLocalizedDescriptionKey: @"未找到要备份的插件"}];
        return nil;
    }

    NSArray<NSString *> *sourcePaths = [self backupablePathsForModel:model];
    if (sourcePaths.count == 0) {
        if (error) *error = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorMissingManifest
                                          userInfo:@{NSLocalizedDescriptionKey: @"没有可备份的 dylib 或 plist 文件"}];
        return nil;
    }

    BOOL (^isCancelled)(void) = ^BOOL { return cancelCheck ? cancelCheck() : NO; };
    NSError *cancelError = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorCancelled
                                          userInfo:@{NSLocalizedDescriptionKey: @"备份任务已取消，未提交数据已清理"}];

    NSString *backupID = [NSUUID UUID].UUIDString;
    NSString *pluginDir = [self.backupsDir stringByAppendingPathComponent:[self safeNameForText:model.pluginID]];
    NSString *backupDir = [pluginDir stringByAppendingPathComponent:backupID];
    NSString *filesDir = [backupDir stringByAppendingPathComponent:@"files"];
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:filesDir withIntermediateDirectories:YES attributes:nil error:error]) return nil;

    if (isCancelled()) {
        [fm removeItemAtPath:backupDir error:nil];
        if (error) *error = cancelError;
        return nil;
    }

    NSUInteger total = sourcePaths.count;
    NSMutableArray<FKBackupFileEntry *> *entries = [NSMutableArray array];
    NSMutableSet<NSString *> *usedNames = [NSMutableSet set];

    for (NSUInteger i = 0; i < total; i++) {
        NSString *source = sourcePaths[i];
        if (isCancelled()) {
            // 取消：清理未提交的半成品目录，不触碰已完成的历史备份。
            [fm removeItemAtPath:backupDir error:nil];
            if (error) *error = cancelError;
            return nil;
        }
        if (progress) progress((double)i / total, source.lastPathComponent);

        FKBackupFileEntry *entry = [self copyBackupFileAtPath:source toFilesDir:filesDir usedNames:usedNames error:error];
        if (!entry) {
            // 备份失败：清理半成品目录，不生成看似完整的备份记录。
            [fm removeItemAtPath:backupDir error:nil];
            return nil;
        }
        [entries addObject:entry];
        if (progress) progress((double)(i + 1) / total, source.lastPathComponent);
    }

    if (progress) progress(1.0, @"manifest.json");

    FKBackupManifest *manifest = [FKBackupManifest new];
    manifest.backupID = backupID;
    manifest.pluginID = model.pluginID;
    manifest.packageID = model.packageID ?: @"";
    manifest.operation = @"backup";
    manifest.createdAt = [NSDate date];
    manifest.formatVersion = @"1";
    manifest.files = entries.copy;

    // manifest 原子写入；失败同样清理半成品。
    NSDictionary *manifestJSON = manifest.JSONDictionary;
    NSData *manifestData = [NSJSONSerialization dataWithJSONObject:manifestJSON options:NSJSONWritingPrettyPrinted error:error];
    if (!manifestData) { [fm removeItemAtPath:backupDir error:nil]; return nil; }
    NSString *manifestPath = [backupDir stringByAppendingPathComponent:@"manifest.json"];
    if (![manifestData writeToFile:manifestPath options:NSDataWritingAtomic error:error]) {
        [fm removeItemAtPath:backupDir error:nil];
        return nil;
    }

    NSDictionary *record = [self recordWithManifest:manifest directory:backupDir];
    self.fileBackups[backupID] = record;
    [self appendIndexWithRecord:record];
    return record;
}

/// 复制单个文件到备份目录并重读校验 SHA-256 一致；失败返回 nil 并填 error。
- (FKBackupFileEntry *)copyBackupFileAtPath:(NSString *)source toFilesDir:(NSString *)filesDir
                                   usedNames:(NSMutableSet<NSString *> *)usedNames error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSDictionary *attrs = [fm attributesOfItemAtPath:source error:error];
    if (!attrs) return nil;

    NSDictionary<NSString *, NSString *> *hash = [FKFileHasher hashForFileAtURL:[NSURL fileURLWithPath:source] error:error];
    if (!hash) return nil;

    NSString *base = source.lastPathComponent.length ? source.lastPathComponent : @"file";
    NSString *targetName = base;
    NSUInteger suffix = 2;
    while ([usedNames containsObject:targetName]) {
        targetName = [NSString stringWithFormat:@"%@-%lu", base, (unsigned long)suffix++];
    }
    [usedNames addObject:targetName];
    NSString *targetPath = [filesDir stringByAppendingPathComponent:targetName];

    if (![fm copyItemAtPath:source toPath:targetPath error:error]) return nil;

    // 重读备份文件并比对 SHA-256，确认复制内容完整。
    NSString *restored = [FKFileHasher SHA256ForFileAtURL:[NSURL fileURLWithPath:targetPath] error:error];
    if (!restored || ![restored isEqualToString:hash[FKFileHashKeySHA256]]) {
        [fm removeItemAtPath:targetPath error:nil];
        if (error) *error = [NSError errorWithDomain:FKBackupManagerErrorDomain code:FKBackupErrorChecksumMismatch
                                          userInfo:@{NSLocalizedDescriptionKey: @"备份文件重读摘要不一致"}];
        return nil;
    }

    FKBackupFileEntry *entry = [FKBackupFileEntry new];
    entry.originalPath = source;
    entry.backupRelPath = [@"files" stringByAppendingPathComponent:targetName];
    entry.size = [attrs[NSFileSize] unsignedLongLongValue];
    entry.fileType = FKBackupFileType(source);
    entry.mode = [NSString stringWithFormat:@"%o", [attrs[NSFilePosixPermissions] unsignedIntValue]];
    entry.owner = [NSString stringWithFormat:@"%@:%@", attrs[NSFileOwnerAccountID] ?: @"?", attrs[NSFileGroupOwnerAccountID] ?: @"?"];
    entry.modificationDate = attrs[NSFileModificationDate];
    if ([attrs[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
        entry.symlinkTarget = [fm destinationOfSymbolicLinkAtPath:source error:nil] ?: @"";
    } else {
        entry.symlinkTarget = @"";
    }
    entry.md5 = hash[FKFileHashKeyMD5];
    entry.sha256 = hash[FKFileHashKeySHA256];
    return entry;
}

/// 由清单生成索引记录。
- (NSDictionary *)recordWithManifest:(FKBackupManifest *)manifest directory:(NSString *)directory {
    return @{
        @"backup_id": manifest.backupID ?: @"",
        @"plugin_id": manifest.pluginID ?: @"",
        @"package_id": manifest.packageID ?: @"",
        @"operation": manifest.operation ?: @"backup",
        @"created_at": FKBackupTimestamp(manifest.createdAt),
        @"file_count": @(manifest.files.count),
        @"directory": directory,
        @"files": manifest.JSONDictionary[@"files"] ?: @[]
    };
}

/// 追加写入 index.json（原子更新），重复备份不覆盖旧记录。
- (void)appendIndexWithRecord:(NSDictionary *)record {
    NSString *indexPath = [self.backupsDir stringByAppendingPathComponent:@"index.json"];
    NSMutableArray<NSMutableDictionary *> *indexRecords = [NSMutableArray array];
    NSData *existing = [NSData dataWithContentsOfFile:indexPath];
    if (existing) {
        NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:existing options:0 error:nil];
        if ([parsed isKindOfClass:NSDictionary.class]) {
            for (id item in parsed[@"backups"]) {
                if ([item isKindOfClass:NSDictionary.class]) [indexRecords addObject:[item mutableCopy]];
            }
        }
    }
    [indexRecords addObject:[record mutableCopy]];
    NSDictionary *index = @{@"backup_format": @"filterkit-file-backup", @"format_version": @1, @"backups": indexRecords.copy};
    NSData *data = [NSJSONSerialization dataWithJSONObject:index options:NSJSONWritingPrettyPrinted error:nil];
    if (data) [data writeToFile:indexPath options:NSDataWritingAtomic error:nil];
}

/// 首次使用时从 index.json 载入历史备份记录。
- (void)loadBackupsIfNeeded {
    if (self.backupsLoaded) return;
    self.backupsLoaded = YES;
    NSString *indexPath = [self.backupsDir stringByAppendingPathComponent:@"index.json"];
    NSData *data = [NSData dataWithContentsOfFile:indexPath];
    if (!data) return;
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![parsed isKindOfClass:NSDictionary.class]) return;
    for (id item in parsed[@"backups"]) {
        if ([item isKindOfClass:NSDictionary.class]) {
            NSString *backupID = item[@"backup_id"];
            if (backupID) self.fileBackups[backupID] = item;
        }
    }
}

- (NSArray<NSDictionary *> *)allBackups {
    [self loadBackupsIfNeeded];
    NSArray<NSDictionary *> *records = self.fileBackups.allValues;
    return [records sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"created_at"] compare:a[@"created_at"] options:NSNumericSearch];
    }];
}

- (NSArray<FKBackupResult *> *)activeBackupResults {
    [self.activeLock lock];
    NSArray<FKBackupResult *> *results = self.activeResults.allValues.copy;
    [self.activeLock unlock];
    // 进行中任务排在历史记录之前；进度高的优先展示。
    return [results sortedArrayUsingComparator:^NSComparisonResult(FKBackupResult *a, FKBackupResult *b) {
        if (a.status != b.status) return a.status < b.status ? NSOrderedAscending : NSOrderedDescending;
        return b.progress > a.progress ? NSOrderedDescending : NSOrderedAscending;
    }];
}

- (void)registerActiveResult:(FKBackupResult *)result {
    if (!result || !result.pluginID.length) return;
    [self.activeLock lock];
    self.activeResults[result.pluginID] = result;
    [self.activeLock unlock];
}

- (void)updateActiveResult:(FKBackupResult *)result {
    if (!result || !result.pluginID.length) return;
    [self.activeLock lock];
    self.activeResults[result.pluginID] = result;
    [self.activeLock unlock];
    NSDictionary *userInfo = @{
        FKBackupNotificationPluginIDKey: result.pluginID ?: @"",
        FKBackupNotificationProgressKey: @(result.progress),
        FKBackupNotificationCurrentFileKey: result.currentFile ?: @""
    };
    [NSNotificationCenter.defaultCenter postNotificationName:FKBackupProgressNotification object:nil userInfo:userInfo];
}

- (void)removeActiveResultForPluginID:(NSString *)pluginID {
    if (!pluginID.length) return;
    [self.activeLock lock];
    [self.activeResults removeObjectForKey:pluginID];
    [self.activeLock unlock];
}

- (NSDictionary *)backupWithID:(NSString *)backupID {
    [self loadBackupsIfNeeded];
    return backupID.length ? self.fileBackups[backupID] : nil;
}

- (NSString *)backupDirectoryForID:(NSString *)backupID {
    NSDictionary *record = [self backupWithID:backupID];
    NSString *directory = record[@"directory"];
    return [directory isKindOfClass:NSString.class] && directory.length ? directory : nil;
}

@end
