#import "FKInjectorProfile.h"

@implementation FKInjectorProfile

+ (instancetype)profileFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKInjectorProfile *profile = [self new];
    profile.injectorID = dict[@"injector_id"] ?: @"";
    profile.name = dict[@"name"] ?: profile.injectorID;
    profile.version = dict[@"version"] ?: @"";

    NSDictionary *cap = [dict[@"capabilities"] isKindOfClass:NSDictionary.class] ? dict[@"capabilities"] : @{};
    profile.filterParsing = [cap[@"filter_parsing"] boolValue];
    profile.appTargeting = [cap[@"app_targeting"] boolValue];
    profile.globalInjection = [cap[@"global_injection"] boolValue];
    // 启停能力以注册表/验证结果为准；字典缺省按未验证处理。
    profile.pluginEnable = [cap[@"plugin_enable"] boolValue];
    profile.pluginDisable = [cap[@"plugin_disable"] boolValue];

    NSDictionary *mgmt = [dict[@"management"] isKindOfClass:NSDictionary.class] ? dict[@"management"] : @{};
    profile.managementMethod = mgmt[@"method"] ?: @"unknown";
    profile.managementVerified = [mgmt[@"verified"] boolValue];
    return profile;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"injector_id": self.injectorID ?: @"",
        @"name": self.name ?: @"",
        @"version": self.version ?: @"",
        @"capabilities": @{
            @"filter_parsing": @(self.filterParsing),
            @"app_targeting": @(self.appTargeting),
            @"global_injection": @(self.globalInjection),
            @"plugin_enable": @(self.pluginEnable),
            @"plugin_disable": @(self.pluginDisable)
        },
        @"management": @{
            @"method": self.managementMethod ?: @"unknown",
            @"verified": @(self.managementVerified)
        }
    };
}

@end
