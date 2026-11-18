#import "FKConfigurationBackup.h"

static NSString *FKConfigBackupTimestamp(NSDate *date) {
    if (!date) return @"";
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter stringFromDate:date];
}

@implementation FKConfigurationBackup

+ (instancetype)backupWithPluginID:(NSString *)pluginID
                       injectorType:(nullable NSString *)injectorType
                 targetAppBundleID:(nullable NSString *)appBundleID
                       operationID:(nullable NSString *)operationID
                originalConfiguration:(NSDictionary *)configuration {
    FKConfigurationBackup *backup = [self new];
    backup.backupID = [NSUUID UUID].UUIDString;
    backup.pluginID = pluginID ?: @"";
    backup.injectorType = injectorType;
    backup.targetAppBundleID = appBundleID;
    backup.operationID = operationID;
    backup.originalConfiguration = configuration ?: @{};
    backup.timestamp = [NSDate date];
    return backup;
}

+ (instancetype)backupFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKConfigurationBackup *backup = [self new];
    backup.backupID = dict[@"backup_id"] ?: [NSUUID UUID].UUIDString;
    backup.pluginID = dict[@"plugin_id"] ?: @"";
    backup.injectorType = dict[@"injector_type"];
    backup.targetAppBundleID = dict[@"target_app_bundle_id"];
    backup.operationID = dict[@"operation_id"];
    backup.operationText = dict[@"operation"];
    backup.configurationHash = dict[@"configuration_hash"];
    if ([dict[@"original_configuration"] isKindOfClass:NSDictionary.class]) {
        backup.originalConfiguration = dict[@"original_configuration"];
    } else {
        backup.originalConfiguration = @{};
    }
    NSString *timestamp = dict[@"timestamp"];
    if ([timestamp isKindOfClass:NSString.class] && timestamp.length) {
        static NSISO8601DateFormatter *formatter;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            formatter = [[NSISO8601DateFormatter alloc] init];
            formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        });
        backup.timestamp = [formatter dateFromString:timestamp];
    } else {
        backup.timestamp = [NSDate date];
    }
    return backup;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"backup_id": self.backupID ?: @"",
        @"injector_type": self.injectorType ?: @"",
        @"target_app_bundle_id": self.targetAppBundleID ?: @"",
        @"plugin_id": self.pluginID ?: @"",
        @"operation": self.operationText ?: @"",
        @"operation_id": self.operationID ?: @"",
        @"configuration_hash": self.configurationHash ?: @"",
        @"original_configuration": self.originalConfiguration ?: @{},
        @"timestamp": FKConfigBackupTimestamp(self.timestamp) ?: @""
    };
}

@end
