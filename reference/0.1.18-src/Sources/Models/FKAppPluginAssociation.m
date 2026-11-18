#import "FKAppPluginAssociation.h"

/// 线程安全的 ISO8601 日期编码；空日期回空串，避免 JSON 出现 nil。
static NSString *FKAssociationDateString(NSDate *_Nullable date) {
    if (!date) return @"";
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter stringFromDate:date];
}

static NSDate *_Nullable FKAssociationDateFromString(NSString *_Nullable raw) {
    if (![raw isKindOfClass:NSString.class] || raw.length == 0) return nil;
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter dateFromString:raw];
}

@implementation FKAppPluginAssociation

+ (nullable instancetype)associationFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    NSString *appBundleID = dict[@"app_bundle_id"];
    NSString *pluginID = dict[@"plugin_id"];
    if (![appBundleID isKindOfClass:NSString.class] || appBundleID.length == 0 ||
        ![pluginID isKindOfClass:NSString.class] || pluginID.length == 0) {
        return nil;
    }
    FKAppPluginAssociation *association = [FKAppPluginAssociation new];
    association.associationID = [dict[@"association_id"] isKindOfClass:NSString.class] ? dict[@"association_id"] : [NSUUID UUID].UUIDString;
    association.appBundleID = appBundleID;
    association.pluginID = pluginID;
    association.createdAt = FKAssociationDateFromString(dict[@"created_at"]) ?: [NSDate date];
    association.updatedAt = FKAssociationDateFromString(dict[@"updated_at"]) ?: association.createdAt;
    association.source = [dict[@"source"] isKindOfClass:NSString.class] && [dict[@"source"] length] ? dict[@"source"] : FKAssociationSourceManual;
    association.status = [dict[@"status"] isKindOfClass:NSString.class] && [dict[@"status"] length] ? dict[@"status"] : FKAssociationStatusAssociated;
    return association;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"association_id": self.associationID ?: @"",
        @"app_bundle_id": self.appBundleID ?: @"",
        @"plugin_id": self.pluginID ?: @"",
        @"created_at": FKAssociationDateString(self.createdAt),
        @"updated_at": FKAssociationDateString(self.updatedAt),
        @"source": self.source ?: FKAssociationSourceManual,
        @"status": self.status ?: FKAssociationStatusAssociated
    };
}

@end
