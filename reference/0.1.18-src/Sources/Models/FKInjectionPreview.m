#import "FKInjectionPreview.h"

static NSString *FKPreviewDateString(NSDate *_Nullable date) {
    if (!date) return @"";
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter stringFromDate:date];
}

static NSDate *_Nullable FKPreviewDateFromString(NSString *_Nullable raw) {
    if (![raw isKindOfClass:NSString.class] || raw.length == 0) return nil;
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter dateFromString:raw];
}

@implementation FKInjectionPreview

+ (nullable instancetype)previewFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    NSString *appBundleID = dict[@"app_bundle_id"];
    NSString *pluginID = dict[@"plugin_id"];
    if (![appBundleID isKindOfClass:NSString.class] || appBundleID.length == 0 ||
        ![pluginID isKindOfClass:NSString.class] || pluginID.length == 0) {
        return nil;
    }
    FKInjectionPreview *preview = [FKInjectionPreview new];
    preview.previewID = [dict[@"preview_id"] isKindOfClass:NSString.class] ? dict[@"preview_id"] : [NSUUID UUID].UUIDString;
    preview.appBundleID = appBundleID;
    preview.pluginID = pluginID;
    preview.dylibPath = [dict[@"dylib_path"] isKindOfClass:NSString.class] ? dict[@"dylib_path"] : @"";
    preview.injectorType = [dict[@"injector_type"] isKindOfClass:NSString.class] ? dict[@"injector_type"] : @"";
    preview.checks = [dict[@"checks"] isKindOfClass:NSArray.class] ? dict[@"checks"] : @[];
    preview.warnings = [dict[@"warnings"] isKindOfClass:NSArray.class] ? dict[@"warnings"] : @[];
    preview.createdAt = FKPreviewDateFromString(dict[@"created_at"]) ?: [NSDate date];
    // 历史快照按持久化值还原；未标注时保守视为仅预览、未改系统。
    preview.previewOnly = [dict[@"preview_only"] isKindOfClass:NSNumber.class] ? [dict[@"preview_only"] boolValue] : YES;
    preview.systemModified = [dict[@"system_modified"] isKindOfClass:NSNumber.class] ? [dict[@"system_modified"] boolValue] : NO;
    preview.result = [dict[@"result"] isKindOfClass:NSString.class] && [dict[@"result"] length] ? dict[@"result"] : FKPreviewResultReady;
    return preview;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"preview_id": self.previewID ?: @"",
        @"app_bundle_id": self.appBundleID ?: @"",
        @"plugin_id": self.pluginID ?: @"",
        @"dylib_path": self.dylibPath ?: @"",
        @"injector_type": self.injectorType ?: @"",
        @"checks": self.checks ?: @[],
        @"warnings": self.warnings ?: @[],
        @"created_at": FKPreviewDateString(self.createdAt),
        @"preview_only": @(self.previewOnly),
        @"system_modified": @(self.systemModified),
        @"result": self.result ?: FKPreviewResultReady
    };
}

@end
