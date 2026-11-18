#import "FKManageModels.h"

#pragma mark - 工具

static NSArray<NSString *> *FKStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (id item in (NSArray *)value) {
        if ([item isKindOfClass:NSString.class]) [result addObject:item];
    }
    return result.copy;
}

static NSString *FKSafeText(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

#pragma mark - FKFilterModel

@implementation FKFilterModel

+ (instancetype)modelWithDictionary:(NSDictionary *)rule filterPath:(NSString *)filterPath {
    FKFilterModel *model = [FKFilterModel new];
    model.filterPath = filterPath ?: @"";
    if (![rule isKindOfClass:NSDictionary.class]) {
        model.bundles = @[];
        model.executables = @[];
        model.classes = @[];
        model.otherKeys = @[];
        model.rawRules = @{};
        model.parseError = @"规则字典缺失";
        return model;
    }
    model.bundles = FKStringArray(rule[@"bundle_ids"]);
    model.executables = FKStringArray(rule[@"executables"]);
    model.classes = FKStringArray(rule[@"classes"]);
    model.otherKeys = FKStringArray(rule[@"other_keys"]);
    model.rawRules = [rule copy];
    model.global = [rule[@"global"] boolValue];
    NSString *configStatus = FKSafeText(rule[@"configuration_status"]);
    if ([configStatus isEqualToString:@"unparseable"]) {
        NSArray *warnings = FKStringArray(rule[@"warnings"]);
        model.parseError = warnings.count ? [warnings componentsJoinedByString:@"; "] : @"Filter plist 解析失败";
    }
    return model;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"filter_path": self.filterPath ?: @"",
        @"bundles": self.bundles ?: @[],
        @"executables": self.executables ?: @[],
        @"classes": self.classes ?: @[],
        @"other_keys": self.otherKeys ?: @[],
        @"global": @(self.global),
        @"parse_error": self.parseError ?: @"",
        @"raw_rules": self.rawRules ?: @{}
    };
}

@end

#pragma mark - FKPackageModel

@implementation FKPackageModel

+ (instancetype)modelWithDictionary:(NSDictionary *)raw {
    FKPackageModel *model = [FKPackageModel new];
    if (![raw isKindOfClass:NSDictionary.class]) return model;
    model.packageID = FKSafeText(raw[@"Package"]);
    model.name = FKSafeText(raw[@"Name"]);
    model.version = FKSafeText(raw[@"Version"]);
    model.status = FKSafeText(raw[@"Status"]);
    model.architecture = FKSafeText(raw[@"Architecture"]);
    model.maintainer = FKSafeText(raw[@"Maintainer"]);
    model.descriptionText = FKSafeText(raw[@"Description"]);
    model.homepage = FKSafeText(raw[@"Homepage"]);
    model.section = FKSafeText(raw[@"Section"]);
    return model;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"package_id": self.packageID ?: @"",
        @"name": self.name ?: @"",
        @"version": self.version ?: @"",
        @"status": self.status ?: @"",
        @"architecture": self.architecture ?: @"",
        @"maintainer": self.maintainer ?: @"",
        @"description": self.descriptionText ?: @"",
        @"homepage": self.homepage ?: @"",
        @"section": self.section ?: @""
    };
}

@end

#pragma mark - FKPluginModel

@implementation FKPluginModel

+ (instancetype)modelWithDictionary:(NSDictionary *)raw {
    FKPluginModel *model = [FKPluginModel new];
    model.raw = [raw copy];
    if (![raw isKindOfClass:NSDictionary.class]) return model;

    model.pluginID = FKSafeText(raw[@"PluginID"]);
    model.name = FKSafeText(raw[@"Name"]);
    model.identifier = FKSafeText(raw[@"Identifier"]);
    model.version = FKSafeText(raw[@"Version"]);
    model.packageID = FKSafeText(raw[@"PackageID"]);
    model.packageCandidates = FKStringArray(raw[@"PackageCandidates"]);
    model.dylibPath = FKSafeText(raw[@"DylibPath"]);
    model.filterPath = FKSafeText(raw[@"PlistPath"]);
    model.source = FKSafeText(raw[@"Source"]);
    model.fileStatus = FKSafeText(raw[@"FileStatus"]);
    model.duplicateFlags = FKStringArray(raw[@"duplicate_flags"]);

    NSDictionary *association = [raw[@"Association"] isKindOfClass:NSDictionary.class] ? raw[@"Association"] : @{};
    model.associationCategory = FKSafeText(association[@"category"]);
    model.associatedBundleIDs = FKStringArray(association[@"matched_bundle_ids"]);
    model.unmatchedBundleIDs = FKStringArray(association[@"unmatched_bundle_ids"]);
    model.matchedExecutables = FKStringArray(association[@"matched_executables"]);
    model.unmatchedExecutables = FKStringArray(association[@"unmatched_executables"]);
    model.isGlobal = [association[@"global"] boolValue];

    // 规则模型：取第一条规则（当前一个插件对应一份 Filter）。
    NSArray *rules = [raw[@"Rules"] isKindOfClass:NSArray.class] ? raw[@"Rules"] : @[];
    NSDictionary *firstRule = [rules firstObject];
    model.filter = [FKFilterModel modelWithDictionary:firstRule filterPath:model.filterPath];

    // 关联类型：区分全局、静态规则匹配、未匹配与未知。
    if (model.isGlobal) {
        model.associationType = @"global";
    } else if (model.associatedBundleIDs.count > 0) {
        model.associationType = @"filter_match";
    } else if ([model.associationCategory isEqualToString:@"unmatched_target"] ||
               [model.associationCategory isEqualToString:@"unresolved_non_bundle_rule"]) {
        model.associationType = @"unmatched";
    } else {
        model.associationType = @"unknown";
    }

    model.integrity = [self integrityForRaw:raw association:association];
    model.integrityStatus = [self integrityText:model.integrity];
    return model;
}

+ (FKPluginIntegrity)integrityForRaw:(NSDictionary *)raw association:(NSDictionary *)association {
    NSString *fileStatus = FKSafeText(raw[@"FileStatus"]);
    NSString *category = FKSafeText(association[@"category"]);
    NSArray *duplicates = FKStringArray(raw[@"duplicate_flags"]);

    // 结构缺失（缺 dylib / plist）或配置无效、不可解析，归为异常。
    if (![fileStatus isEqualToString:@"complete"]) return FKPluginIntegrityAbnormal;
    if ([category isEqualToString:@"invalid_configuration"] || [category isEqualToString:@"unparseable"]) return FKPluginIntegrityAbnormal;

    // 有重复归属/重复载荷等标记，或存在未匹配规则，归为警告。
    NSArray *unmatched = FKStringArray(association[@"unmatched_bundle_ids"]);
    NSArray *unmatchedExec = FKStringArray(association[@"unmatched_executables"]);
    if (duplicates.count > 0 || unmatched.count > 0 || unmatchedExec.count > 0) return FKPluginIntegrityWarning;

    // 结构完整、配置有效且已关联或为全局，视为完整；其余暂列未知。
    NSArray *matched = FKStringArray(association[@"matched_bundle_ids"]);
    BOOL global = [association[@"global"] boolValue];
    if (matched.count > 0 || global) return FKPluginIntegrityOK;
    return FKPluginIntegrityUnknown;
}

+ (NSString *)integrityText:(FKPluginIntegrity)integrity {
    switch (integrity) {
        case FKPluginIntegrityOK: return @"完整";
        case FKPluginIntegrityWarning: return @"警告";
        case FKPluginIntegrityAbnormal: return @"异常";
        case FKPluginIntegrityUnknown: return @"未知";
    }
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"plugin_id": self.pluginID ?: @"",
        @"name": self.name ?: @"",
        @"identifier": self.identifier ?: @"",
        @"version": self.version ?: @"",
        @"package_id": self.packageID ?: @"",
        @"package_candidates": self.packageCandidates ?: @[],
        @"dylib_path": self.dylibPath ?: @"",
        @"filter_path": self.filterPath ?: @"",
        @"source": self.source ?: @"",
        @"file_status": self.fileStatus ?: @"",
        @"association_category": self.associationCategory ?: @"",
        @"association_type": self.associationType ?: @"",
        @"associated_apps": self.associatedBundleIDs ?: @[],
        @"unmatched_bundle_ids": self.unmatchedBundleIDs ?: @[],
        @"matched_executables": self.matchedExecutables ?: @[],
        @"unmatched_executables": self.unmatchedExecutables ?: @[],
        @"is_global": @(self.isGlobal),
        @"integrity_status": self.integrityStatus ?: @"未知",
        @"duplicate_flags": self.duplicateFlags ?: @[],
        @"filter": self.filter.JSONDictionary ?: @{}
    };
}

@end

#pragma mark - FKAppModel

@implementation FKAppModel

+ (instancetype)modelWithDictionary:(NSDictionary *)raw {
    FKAppModel *model = [FKAppModel new];
    if (![raw isKindOfClass:NSDictionary.class]) return model;
    model.bundleID = FKSafeText(raw[@"bundle_id"]);
    model.name = FKSafeText(raw[@"name"]);
    model.version = FKSafeText(raw[@"version"]);
    model.versionSource = FKSafeText(raw[@"version_source"]);
    model.buildVersion = FKSafeText(raw[@"build_version"]);
    model.bundlePath = FKSafeText(raw[@"bundle_path"]);
    model.executable = FKSafeText(raw[@"executable"]);
    model.isSystem = [raw[@"is_system"] boolValue];
    model.iconPath = FKSafeText(raw[@"icon_path"]);
    model.iconSource = FKSafeText(raw[@"icon_source"]);
    model.pluginIDs = FKStringArray(raw[@"plugins"]);
    return model;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"bundle_id": self.bundleID ?: @"",
        @"name": self.name ?: @"",
        @"version": self.version ?: @"",
        @"version_source": self.versionSource ?: @"",
        @"build_version": self.buildVersion ?: @"",
        @"bundle_path": self.bundlePath ?: @"",
        @"executable": self.executable ?: @"",
        @"is_system": @(self.isSystem),
        @"icon_path": self.iconPath ?: @"",
        @"icon_source": self.iconSource ?: @"",
        @"plugin_ids": self.pluginIDs ?: @[]
    };
}

@end
