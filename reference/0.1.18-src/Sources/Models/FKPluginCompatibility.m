#import "FKPluginCompatibility.h"

@implementation FKPluginCompatibility

+ (NSString *)statusText:(FKCompatibilityStatus)status {
    switch (status) {
        case FKCompatibilityStatusCompatible: return @"兼容";
        case FKCompatibilityStatusPartiallyCompatible: return @"部分兼容";
        case FKCompatibilityStatusIncompatible: return @"不兼容";
        case FKCompatibilityStatusUnsupported: return @"不支持";
        case FKCompatibilityStatusUnknown:
        default: return @"未知";
    }
}

+ (NSString *)statusCode:(FKCompatibilityStatus)status {
    switch (status) {
        case FKCompatibilityStatusCompatible: return @"compatible";
        case FKCompatibilityStatusPartiallyCompatible: return @"partially_compatible";
        case FKCompatibilityStatusIncompatible: return @"incompatible";
        case FKCompatibilityStatusUnsupported: return @"unsupported";
        case FKCompatibilityStatusUnknown:
        default: return @"unknown";
    }
}

+ (FKCompatibilityStatus)statusFromCode:(NSString *_Nullable)code {
    if (![code isKindOfClass:NSString.class]) return FKCompatibilityStatusUnknown;
    if ([code isEqualToString:@"compatible"]) return FKCompatibilityStatusCompatible;
    if ([code isEqualToString:@"partially_compatible"]) return FKCompatibilityStatusPartiallyCompatible;
    if ([code isEqualToString:@"incompatible"]) return FKCompatibilityStatusIncompatible;
    if ([code isEqualToString:@"unsupported"]) return FKCompatibilityStatusUnsupported;
    return FKCompatibilityStatusUnknown;
}

+ (nullable instancetype)compatibilityFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKPluginCompatibility *compatibility = [FKPluginCompatibility new];
    compatibility.pluginID = [dict[@"plugin_id"] isKindOfClass:NSString.class] ? dict[@"plugin_id"] : @"";
    compatibility.appBundleID = [dict[@"app_bundle_id"] isKindOfClass:NSString.class] ? dict[@"app_bundle_id"] : @"";
    compatibility.status = [self statusFromCode:dict[@"status"]];
    compatibility.checks = [dict[@"checks"] isKindOfClass:NSArray.class] ? dict[@"checks"] : @[];
    compatibility.conflicts = [dict[@"conflicts"] isKindOfClass:NSArray.class] ? dict[@"conflicts"] : @[];
    compatibility.warnings = [dict[@"warnings"] isKindOfClass:NSArray.class] ? dict[@"warnings"] : @[];
    return compatibility;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"plugin_id": self.pluginID ?: @"",
        @"app_bundle_id": self.appBundleID ?: @"",
        @"status": [FKPluginCompatibility statusCode:self.status],
        @"status_text": [FKPluginCompatibility statusText:self.status],
        @"checks": self.checks ?: @[],
        @"conflicts": self.conflicts ?: @[],
        @"warnings": self.warnings ?: @[]
    };
}

@end
