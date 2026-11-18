#import "FKBackupResult.h"

@implementation FKBackupResult

+ (NSString *)codeForStatus:(FKBackupStatus)status {
    switch (status) {
        case FKBackupStatusPending:    return @"pending";
        case FKBackupStatusRunning:     return @"running";
        case FKBackupStatusVerifying:   return @"verifying";
        case FKBackupStatusCompleted:  return @"completed";
        case FKBackupStatusFailed:      return @"failed";
        case FKBackupStatusCancelled:   return @"cancelled";
    }
    return @"unknown";
}

+ (NSString *)textForStatus:(FKBackupStatus)status {
    switch (status) {
        case FKBackupStatusPending:    return @"等待备份";
        case FKBackupStatusRunning:     return @"正在备份";
        case FKBackupStatusVerifying:   return @"正在校验";
        case FKBackupStatusCompleted:  return @"备份完整";
        case FKBackupStatusFailed:      return @"备份失败";
        case FKBackupStatusCancelled:   return @"已取消";
    }
    return @"未知";
}

- (NSDictionary *)JSONDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"status"] = [FKBackupResult codeForStatus:self.status];
    json[@"status_text"] = [FKBackupResult textForStatus:self.status];
    json[@"backup_id"] = self.backupID ?: @"";
    json[@"plugin_id"] = self.pluginID ?: @"";
    json[@"file_count"] = @(self.fileCount);
    json[@"total_size_bytes"] = @(self.totalSizeBytes);
    json[@"current_file"] = self.currentFile ?: @"";
    json[@"progress"] = @(self.progress);
    json[@"md5_recorded"] = @(self.md5Recorded);
    json[@"sha256_verified"] = @(self.sha256Verified);
    json[@"manifest_generated"] = @(self.manifestGenerated);
    if (self.error) json[@"error"] = self.error.localizedDescription ?: @"";
    if (self.record) json[@"record"] = self.record;
    return json.copy;
}

@end
