#import "FKBackupValidator.h"
#import "FKFileHasher.h"
#import "FKManageModels.h"

/// 轻量文件粗类型判定：优先 Mach-O 头 magic，其次 plist 扩展名，与备份清单口径一致。
static NSString *FKCurrentFileType(NSString *path) {
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

@implementation FKBackupValidator

+ (BOOL)validateBackupAtDirectory:(NSString *)dirPath manifest:(FKBackupManifest *)manifest error:(NSError **)error {
    if (dirPath.length == 0 || !manifest) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError
                                          userInfo:@{NSLocalizedDescriptionKey: @"备份目录或清单缺失"}];
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    for (FKBackupFileEntry *entry in manifest.files) {
        NSString *filePath = [dirPath stringByAppendingPathComponent:entry.backupRelPath];
        if (![fm fileExistsAtPath:filePath]) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError
                                              userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"备份文件缺失：%@", entry.backupRelPath]}];
            return NO;
        }
        NSError *hashError = nil;
        NSString *actual = [FKFileHasher SHA256ForFileAtURL:[NSURL fileURLWithPath:filePath] error:&hashError];
        if (!actual) {
            if (error) *error = hashError ?: [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError
                                                            userInfo:@{NSLocalizedDescriptionKey: @"备份文件无法读取"}];
            return NO;
        }
        if (entry.sha256.length && ![actual isEqualToString:entry.sha256]) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError
                                              userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"备份摘要不一致：%@", entry.backupRelPath]}];
            return NO;
        }
    }
    return YES;
}

+ (NSDictionary *)restorePreviewForManifest:(FKBackupManifest *)manifest currentModel:(FKPluginModel *)model {
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];
    FKRestoreStatus status = FKRestoreStatusUnknown;

    if (!manifest) {
        [reasons addObject:@"备份清单缺失"];
        return [self previewWithStatus:status reasons:reasons];
    }
    if (!model) {
        status = FKRestoreStatusPathMismatch;
        [reasons addObject:@"备份后插件已不在当前扫描结果中，需人工确认"];
        return [self previewWithStatus:status reasons:reasons];
    }

    // 软件包归属比对。
    if (model.packageID.length && ![model.packageID isEqualToString:manifest.packageID]) {
        status = FKRestoreStatusPackageMismatch;
        [reasons addObject:[NSString stringWithFormat:@"软件包归属变化：备份 %@，当前 %@", manifest.packageID ?: @"未知", model.packageID]];
        return [self previewWithStatus:status reasons:reasons];
    }

    // 路径与当前文件变化比对（按 dylib 与 plist 条目分别核对）。
    FKBackupFileEntry *dylibEntry = nil;
    FKBackupFileEntry *plistEntry = nil;
    for (FKBackupFileEntry *entry in manifest.files) {
        if ([entry.originalPath.pathExtension.lowercaseString isEqualToString:@"dylib"]) dylibEntry = entry;
        else if ([entry.originalPath.pathExtension.lowercaseString isEqualToString:@"plist"]) plistEntry = entry;
    }

    if (dylibEntry && model.dylibPath.length && ![dylibEntry.originalPath isEqualToString:model.dylibPath]) {
        status = FKRestoreStatusPathMismatch;
        [reasons addObject:@"dylib 路径与备份时不一致"];
        return [self previewWithStatus:status reasons:reasons];
    }
    if (plistEntry && model.filterPath.length && ![plistEntry.originalPath isEqualToString:model.filterPath]) {
        status = FKRestoreStatusPathMismatch;
        [reasons addObject:@"Filter plist 路径与备份时不一致"];
        return [self previewWithStatus:status reasons:reasons];
    }

    // 当前目标文件哈希与备份摘要比对；读不到则归证据不足，不臆断。
    NSString *currentPath = model.dylibPath.length ? model.dylibPath : model.filterPath;
    FKBackupFileEntry *targetEntry = currentPath.length ? (dylibEntry ?: plistEntry) : nil;
    if (currentPath.length && targetEntry) {
        BOOL isDir = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:currentPath isDirectory:&isDir] && !isDir) {
            NSError *hashError = nil;
            NSString *currentHash = [FKFileHasher SHA256ForFileAtURL:[NSURL fileURLWithPath:currentPath] error:&hashError];
            if (currentHash && targetEntry.sha256.length) {
                if ([currentHash isEqualToString:targetEntry.sha256]) {
                    status = FKRestoreStatusSafeToRestore;
                    [reasons addObject:@"当前目标文件与备份摘要一致，未检测到改动"];
                } else {
                    status = FKRestoreStatusTargetModified;
                    [reasons addObject:@"备份后当前目标文件已被修改，直接恢复可能覆盖新版本"];
                }
            } else {
                [reasons addObject:@"当前文件哈希无法读取，状态证据不足"];
            }
            // 权限位与文件类型只读比对；不一致仅提示，0.1.2 不自动恢复元数据。
            NSDictionary *curAttrs = [NSFileManager.defaultManager attributesOfItemAtPath:currentPath error:nil];
            if (curAttrs) {
                NSString *curMode = [NSString stringWithFormat:@"%o", [curAttrs[NSFilePosixPermissions] unsignedIntValue]];
                if (targetEntry.mode.length && ![curMode isEqualToString:targetEntry.mode]) {
                    [reasons addObject:[NSString stringWithFormat:@"当前权限 %@ 与备份记录 %@ 不一致", curMode, targetEntry.mode]];
                }
                NSString *curType = FKCurrentFileType(currentPath);
                if (targetEntry.fileType.length && ![curType isEqualToString:targetEntry.fileType]) {
                    [reasons addObject:[NSString stringWithFormat:@"当前文件类型 %@ 与备份记录 %@ 不一致", curType, targetEntry.fileType]];
                }
            }
        } else {
            [reasons addObject:@"当前目标文件不存在，状态证据不足"];
        }
    } else {
        [reasons addObject:@"缺少可比对的目标文件条目"];
    }

    return [self previewWithStatus:status reasons:reasons];
}

+ (NSDictionary *)previewWithStatus:(FKRestoreStatus)status reasons:(NSArray<NSString *> *)reasons {
    return @{
        @"status": @(status),
        @"code": [self codeForStatus:status],
        @"text": [self textForStatus:status],
        @"reasons": reasons.copy
    };
}

+ (NSString *)textForStatus:(FKRestoreStatus)status {
    switch (status) {
        case FKRestoreStatusSafeToRestore: return @"理论可恢复（未执行覆盖）";
        case FKRestoreStatusTargetModified: return @"目标文件已被改动";
        case FKRestoreStatusBackupCorrupted: return @"备份已损坏";
        case FKRestoreStatusPackageMismatch: return @"软件包归属变化";
        case FKRestoreStatusPathMismatch: return @"路径或归属不匹配";
        case FKRestoreStatusUnknown: return @"无法判定";
    }
    return @"无法判定";
}

+ (NSString *)codeForStatus:(FKRestoreStatus)status {
    switch (status) {
        case FKRestoreStatusSafeToRestore: return @"SAFE_TO_RESTORE";
        case FKRestoreStatusTargetModified: return @"TARGET_MODIFIED";
        case FKRestoreStatusBackupCorrupted: return @"BACKUP_CORRUPTED";
        case FKRestoreStatusPackageMismatch: return @"PACKAGE_MISMATCH";
        case FKRestoreStatusPathMismatch: return @"PATH_MISMATCH";
        case FKRestoreStatusUnknown: return @"UNKNOWN";
    }
    return @"UNKNOWN";
}

@end
