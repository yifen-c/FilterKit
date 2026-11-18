#import "FKBackupTests.h"
#import "FKBackupManifest.h"

@implementation FKBackupTests

+ (NSUInteger)checkCount { return 5; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // 1. 文件条目字典往返保留路径、大小与摘要。
    FKBackupFileEntry *entry = [FKBackupFileEntry new];
    entry.originalPath = @"/var/jb/usr/lib/example.dylib";
    entry.backupRelPath = @"files/example.dylib";
    entry.size = 2048;
    entry.fileType = @"mach_o";
    entry.sha256 = @"deadbeef";
    entry.md5 = @"cafe";

    NSDictionary *entryJSON = entry.JSONDictionary;
    FKBackupFileEntry *restored = [FKBackupFileEntry entryFromDictionary:entryJSON];
    if (restored.size != 2048) [failures addObject:@"备份条目大小往返错误"];
    if (![restored.sha256 isEqualToString:@"deadbeef"]) [failures addObject:@"备份条目 SHA-256 往返丢失"];
    if (![restored.originalPath isEqualToString:entry.originalPath]) [failures addObject:@"备份条目原始路径往返丢失"];

    // 2. 清单字典往返保留备份 ID、插件 ID 与文件条目数。
    FKBackupManifest *manifest = [FKBackupManifest new];
    manifest.backupID = @"bk-001";
    manifest.pluginID = @"com.test.example:example";
    manifest.packageID = @"com.test.example";
    manifest.operation = @"backup";
    manifest.formatVersion = @"1";
    manifest.files = @[entry];

    NSDictionary *manifestJSON = manifest.JSONDictionary;
    FKBackupManifest *restoredManifest = [FKBackupManifest manifestFromDictionary:manifestJSON];
    if (![restoredManifest.backupID isEqualToString:@"bk-001"]) [failures addObject:@"清单 backup_id 往返丢失"];
    if (restoredManifest.files.count != 1) [failures addObject:@"清单文件条目数往返错误"];

    return failures.copy;
}

@end
