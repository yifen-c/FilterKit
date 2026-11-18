#import "FKBackupManifest.h"

static NSString *FKManifestTimestamp(NSDate *date) {
    if (!date) return @"";
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter stringFromDate:date];
}

static NSDate *FKDateFromTimestamp(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [[NSISO8601DateFormatter new] dateFromString:value];
    }
    return nil;
}

/// 轻量文件粗类型判定：优先 Mach-O 头 magic，其次 plist 扩展名，与诊断分析口径保持一致。
@implementation FKBackupFileEntry

- (NSDictionary *)JSONDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"original_path"] = self.originalPath ?: @"";
    dict[@"backup_rel_path"] = self.backupRelPath ?: @"";
    dict[@"size"] = @(self.size);
    dict[@"file_type"] = self.fileType ?: @"unknown";
    dict[@"mode"] = self.mode ?: @"";
    dict[@"owner"] = self.owner ?: @"";
    dict[@"modification_date"] = FKManifestTimestamp(self.modificationDate);
    dict[@"symlink_target"] = self.symlinkTarget ?: @"";
    dict[@"md5"] = self.md5 ?: @"";
    dict[@"sha256"] = self.sha256 ?: @"";
    return dict.copy;
}

+ (instancetype)entryFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKBackupFileEntry *entry = [self new];
    entry.originalPath = dict[@"original_path"];
    entry.backupRelPath = dict[@"backup_rel_path"];
    entry.size = [dict[@"size"] unsignedLongLongValue];
    entry.fileType = dict[@"file_type"];
    entry.mode = dict[@"mode"];
    entry.owner = dict[@"owner"];
    entry.modificationDate = FKDateFromTimestamp(dict[@"modification_date"]);
    entry.symlinkTarget = dict[@"symlink_target"];
    entry.md5 = dict[@"md5"];
    entry.sha256 = dict[@"sha256"];
    return entry;
}

@end

@implementation FKBackupManifest

- (NSDictionary *)JSONDictionary {
    NSMutableArray *fileDicts = [NSMutableArray array];
    for (FKBackupFileEntry *entry in self.files) [fileDicts addObject:entry.JSONDictionary];
    return @{
        @"backup_id": self.backupID ?: @"",
        @"plugin_id": self.pluginID ?: @"",
        @"package_id": self.packageID ?: @"",
        @"operation": self.operation ?: @"",
        @"created_at": FKManifestTimestamp(self.createdAt),
        @"format_version": self.formatVersion ?: @"1",
        @"files": fileDicts.copy
    };
}

+ (instancetype)manifestFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKBackupManifest *manifest = [self new];
    manifest.backupID = dict[@"backup_id"];
    manifest.pluginID = dict[@"plugin_id"];
    manifest.packageID = dict[@"package_id"];
    manifest.operation = dict[@"operation"];
    manifest.createdAt = FKDateFromTimestamp(dict[@"created_at"]);
    manifest.formatVersion = dict[@"format_version"];
    NSMutableArray *files = [NSMutableArray array];
    for (id item in [dict[@"files"] isKindOfClass:NSArray.class] ? dict[@"files"] : @[]) {
        FKBackupFileEntry *entry = [FKBackupFileEntry entryFromDictionary:item];
        if (entry) [files addObject:entry];
    }
    manifest.files = files.copy;
    return manifest;
}

@end
