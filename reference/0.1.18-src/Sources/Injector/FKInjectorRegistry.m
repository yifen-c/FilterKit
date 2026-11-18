#import "FKInjectorRegistry.h"
#import "FKManageModels.h"

@implementation FKInjectorRegistry

/// 构造一条基线画像。启停能力与管理方式在真实验证前保持未验证。
- (FKInjectorProfile *)profileWithID:(NSString *)identifier
                                 name:(NSString *)name
                        filterParsing:(BOOL)filterParsing
                         appTargeting:(BOOL)appTargeting
                       globalInjection:(BOOL)globalInjection
                      managementMethod:(NSString *)method {
    FKInjectorProfile *profile = [FKInjectorProfile new];
    profile.injectorID = identifier;
    profile.name = name;
    profile.filterParsing = filterParsing;
    profile.appTargeting = appTargeting;
    profile.globalInjection = globalInjection;
    // 0.1.4 未接入已验证的启停机制，启停能力保持关闭。
    profile.pluginEnable = NO;
    profile.pluginDisable = NO;
    profile.managementMethod = method;
    profile.managementVerified = NO;
    return profile;
}

- (NSDictionary<NSString *, FKInjectorProfile *> *)builtinProfiles {
    NSMutableDictionary<NSString *, FKInjectorProfile *> *profiles = [NSMutableDictionary dictionary];
    FKInjectorProfile *libhooker = [self profileWithID:@"libhooker" name:@"libhooker"
                                        filterParsing:YES appTargeting:YES globalInjection:YES
                                       managementMethod:@"filter_file"];
    FKInjectorProfile *ellekit = [self profileWithID:@"ellekit" name:@"ElleKit"
                                      filterParsing:YES appTargeting:YES globalInjection:YES
                                     managementMethod:@"filter_file"];
    FKInjectorProfile *substrate = [self profileWithID:@"substrate" name:@"CydiaSubstrate"
                                        filterParsing:NO appTargeting:YES globalInjection:YES
                                       managementMethod:@"none"];
    FKInjectorProfile *substitute = [self profileWithID:@"substitute" name:@"Substitute"
                                         filterParsing:NO appTargeting:YES globalInjection:YES
                                        managementMethod:@"none"];
    for (FKInjectorProfile *p in @[libhooker, ellekit, substrate, substitute]) profiles[p.injectorID] = p;
    return profiles.copy;
}

- (FKInjectorProfile *)profileForInjector:(NSString *)injectorID {
    if (![injectorID isKindOfClass:NSString.class] || injectorID.length == 0) return nil;
    return [self builtinProfiles][injectorID];
}

- (FKInjectorCompatibility *)compatibilityForPlugin:(FKPluginModel *)plugin
                                            injector:(FKInjectorModel *)injector {
    FKInjectorCompatibility *result = [FKInjectorCompatibility new];
    result.pluginID = plugin.pluginID ?: @"";
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];

    if (!injector || !injector.detected) {
        result.injectorID = @"unknown";
        result.status = FKInjectorCompatibilityStatusUnknown;
        [reasons addObject:@"未识别到注入器，无法评估兼容性"];
        result.reasons = reasons.copy;
        return result;
    }
    result.injectorID = injector.injectorID;
    FKInjectorProfile *profile = [self profileForInjector:injector.injectorID];
    if (!profile) {
        result.status = FKInjectorCompatibilityStatusUnknown;
        [reasons addObject:@"注入器能力未登记，兼容性证据不足"];
        result.reasons = reasons.copy;
        return result;
    }

    BOOL hasFilter = plugin.filter != nil;
    BOOL needsFilter = hasFilter && plugin.filterPath.length > 0;
    BOOL global = plugin.isGlobal;
    BOOL needsTargeting = !global && plugin.associatedBundleIDs.count > 0;

    // 规则解析能力核对。
    if (needsFilter && !profile.filterParsing) {
        result.status = FKInjectorCompatibilityStatusIncompatible;
        [reasons addObject:@"当前注入器不解析 Filter 规则"];
        result.reasons = reasons.copy;
        return result;
    }
    // 定向注入能力核对。
    if (needsTargeting && !profile.appTargeting) {
        result.status = FKInjectorCompatibilityStatusIncompatible;
        [reasons addObject:@"当前注入器不支持按 App 定向注入"];
        result.reasons = reasons.copy;
        return result;
    }
    // 全局注入能力核对。
    if (global && !profile.globalInjection) {
        result.status = FKInjectorCompatibilityStatusIncompatible;
        [reasons addObject:@"当前注入器不支持全局注入"];
        result.reasons = reasons.copy;
        return result;
    }

    // 证据级别不足时降为 Partial，不臆断完全兼容。
    if ([injector.evidenceLevel isEqualToString:@"unknown"]) {
        result.status = FKInjectorCompatibilityStatusUnknown;
        [reasons addObject:@"注入器证据不足，兼容性待确认"];
    } else if ([injector.evidenceLevel isEqualToString:@"partial"]) {
        result.status = FKInjectorCompatibilityStatusPartial;
        [reasons addObject:@"注入器版本或归属证据不完整"];
    } else {
        result.status = FKInjectorCompatibilityStatusCompatible;
        [reasons addObject:@"规则与注入方式受当前注入器支持"];
    }
    result.reasons = reasons.copy;
    return result;
}

@end
