#import "FKCompatibilityManager.h"
#import "FKInjectionPreview.h"

/// 构造单条检查项字典。
static NSDictionary *FKCheck(NSString *key, NSString *status, NSString *detail) {
    return @{@"key": key ?: @"", @"status": status ?: FKCheckStatusUnknown, @"detail": detail ?: @""};
}

@implementation FKCompatibilityManager

- (FKPluginCompatibility *)evaluatePlugin:(FKPluginModel *)plugin
                                    forApp:(FKAppModel *)app
                               injectorType:(NSString *)injectorType
                          alreadyAssociated:(BOOL)alreadyAssociated {
    FKPluginCompatibility *result = [FKPluginCompatibility new];
    result.pluginID = plugin.pluginID ?: @"";
    result.appBundleID = app.bundleID ?: @"";

    NSMutableArray<NSDictionary *> *checks = [NSMutableArray array];
    NSMutableArray<NSString *> *conflicts = [NSMutableArray array];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];

    // App 检查：Bundle ID 有效性。
    if (app.bundleID.length) {
        [checks addObject:FKCheck(@"app", FKCheckStatusPass, [NSString stringWithFormat:@"目标 App：%@", app.name.length ? app.name : app.bundleID])];
    } else {
        [checks addObject:FKCheck(@"app", FKCheckStatusFail, @"目标 App 缺少有效 Bundle ID")];
    }

    // Plugin 文件存在与可读（只读访问，不写入）。
    NSString *dylibPath = plugin.dylibPath ?: @"";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (dylibPath.length == 0) {
        [checks addObject:FKCheck(@"file_exists", FKCheckStatusFail, @"未定位到 dylib 文件路径")];
    } else if ([fm fileExistsAtPath:dylibPath]) {
        [checks addObject:FKCheck(@"file_exists", FKCheckStatusPass, dylibPath)];
        if ([fm isReadableFileAtPath:dylibPath]) {
            [checks addObject:FKCheck(@"file_readable", FKCheckStatusPass, @"文件可读取")];
        } else {
            [checks addObject:FKCheck(@"file_readable", FKCheckStatusFail, @"文件不可读取")];
        }
    } else {
        [checks addObject:FKCheck(@"file_exists", FKCheckStatusFail, [NSString stringWithFormat:@"dylib 不存在：%@", dylibPath])];
        [checks addObject:FKCheck(@"file_readable", FKCheckStatusUnknown, @"文件不存在，跳过可读性检查")];
    }

    // Mach-O 类型 / 架构 / Install Name / 动态依赖：0.1.6 不做二进制深度解析，证据不足保守归 Unknown。
    [checks addObject:FKCheck(@"macho_type", FKCheckStatusUnknown, @"未解析 Mach-O 类型，待后续版本静态分析")];
    [checks addObject:FKCheck(@"architecture", FKCheckStatusUnknown, @"未解析目标架构，不能据此保证可运行")];
    [checks addObject:FKCheck(@"install_name", FKCheckStatusUnknown, @"未读取 Install Name")];
    [checks addObject:FKCheck(@"dependencies", FKCheckStatusUnknown, @"动态依赖未解析")];

    // Injector 检查：仅依据当前识别到的注入器类型；未识别不臆断支持。
    if (injectorType.length) {
        [checks addObject:FKCheck(@"injector", FKCheckStatusPass, [NSString stringWithFormat:@"当前注入器：%@", injectorType])];
    } else {
        [checks addObject:FKCheck(@"injector", FKCheckStatusUnknown, @"未识别注入器，配置格式兼容性待确认")];
    }

    // Filter 解析：复用扫描规则模型；解析失败保留原因。
    if (plugin.filter) {
        if (plugin.filter.parseError.length) {
            [checks addObject:FKCheck(@"filter", FKCheckStatusWarn, plugin.filter.parseError)];
            [warnings addObject:[NSString stringWithFormat:@"Filter 规则解析异常：%@", plugin.filter.parseError]];
        } else {
            [checks addObject:FKCheck(@"filter", FKCheckStatusPass, plugin.filter.global ? @"全局规则" : @"已解析目标规则")];
        }
    } else {
        [checks addObject:FKCheck(@"filter", FKCheckStatusUnknown, @"缺少 Filter 规则证据")];
    }

    // 重复关联提示。
    if (alreadyAssociated) {
        [conflicts addObject:@"该 App 已关联此插件，属于重复关联"];
    }

    // 缺乏运行时兼容证据：静态检查不能证明插件实际可运行。
    [warnings addObject:@"运行时兼容性未知：静态检查通过不代表插件一定可正常运行"];

    result.checks = checks.copy;
    result.conflicts = conflicts.copy;
    result.warnings = warnings.copy;
    result.status = [self summarizeStatusFromChecks:checks conflicts:conflicts];
    return result;
}

/// 按逐项检查保守汇总：存在 fail → 不兼容；存在 warn/unknown → 部分兼容；全 pass → 兼容。
- (FKCompatibilityStatus)summarizeStatusFromChecks:(NSArray<NSDictionary *> *)checks conflicts:(NSArray<NSString *> *)conflicts {
    BOOL hasFail = NO, hasWarn = NO, hasUnknown = NO;
    for (NSDictionary *check in checks) {
        NSString *status = check[@"status"];
        if ([status isEqualToString:FKCheckStatusFail]) hasFail = YES;
        else if ([status isEqualToString:FKCheckStatusWarn]) hasWarn = YES;
        else if ([status isEqualToString:FKCheckStatusUnknown]) hasUnknown = YES;
    }
    if (hasFail) return FKCompatibilityStatusIncompatible;
    if (conflicts.count > 0) return FKCompatibilityStatusPartiallyCompatible;
    if (hasWarn || hasUnknown) return FKCompatibilityStatusPartiallyCompatible;
    return FKCompatibilityStatusCompatible;
}

- (NSArray<NSDictionary *> *)detectConflictsAmongPlugins:(NSArray<FKPluginModel *> *)plugins {
    NSMutableArray<NSDictionary *> *conflicts = [NSMutableArray array];

    // 1. 同一 dylib 路径被重复发现。
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *byDylib = [NSMutableDictionary dictionary];
    // 2. Filter 共享相同目标 Bundle。
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *byBundle = [NSMutableDictionary dictionary];

    for (FKPluginModel *plugin in plugins) {
        NSString *dylib = plugin.dylibPath;
        if (dylib.length) {
            byDylib[dylib] = byDylib[dylib] ?: [NSMutableArray array];
            [byDylib[dylib] addObject:plugin.pluginID];
        }
        for (NSString *bundle in plugin.filter.bundles ?: @[]) {
            if (bundle.length && ![bundle isEqualToString:@"*"]) {
                byBundle[bundle] = byBundle[bundle] ?: [NSMutableArray array];
                [byBundle[bundle] addObject:plugin.pluginID];
            }
        }
    }

    for (NSString *dylib in byDylib) {
        NSArray<NSString *> *ids = byDylib[dylib];
        if (ids.count > 1) {
            [conflicts addObject:@{
                @"type": @"duplicate_dylib",
                @"message": [NSString stringWithFormat:@"同一 dylib 被 %lu 个插件记录：%@", (unsigned long)ids.count, dylib],
                @"plugin_ids": ids
            }];
        }
    }

    for (NSString *bundle in byBundle) {
        NSArray<NSString *> *ids = byBundle[bundle];
        if (ids.count > 1) {
            [conflicts addObject:@{
                @"type": @"shared_filter_target",
                @"message": [NSString stringWithFormat:@"多个插件 Filter 同时指向 App %@，需确认是否配置冲突", bundle],
                @"plugin_ids": ids
            }];
        }
    }

    return conflicts.copy;
}

@end
