#import "FKAppManager.h"

@interface FKAppManager ()
@property (nonatomic, copy) NSArray<FKAppModel *> *apps;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FKAppModel *> *byBundle;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<FKPluginModel *> *> *pluginsByBundle;
@property (nonatomic, assign) BOOL hasGlobalPlugin;
@end

@implementation FKAppManager

- (instancetype)initWithApps:(NSArray<NSDictionary *> *)apps plugins:(NSArray<FKPluginModel *> *)plugins {
    if ((self = [super init])) {
        NSMutableArray<FKAppModel *> *items = [NSMutableArray array];
        _byBundle = [NSMutableDictionary dictionary];
        _pluginsByBundle = [NSMutableDictionary dictionary];

        for (NSDictionary *raw in apps ?: @[]) {
            FKAppModel *model = [FKAppModel modelWithDictionary:raw];
            if (!model.bundleID.length) continue;
            [items addObject:model];
            _byBundle[model.bundleID] = model;
        }

        // 由插件侧关联结果反向填充 App 的插件 ID，不依赖扫描字典里可能缺失的反向索引。
        for (FKPluginModel *plugin in plugins ?: @[]) {
            if (plugin.isGlobal) _hasGlobalPlugin = YES;
            for (NSString *bundleID in plugin.associatedBundleIDs) {
                if (!bundleID.length) continue;
                NSMutableArray *list = _pluginsByBundle[bundleID];
                if (!list) { list = [NSMutableArray array]; _pluginsByBundle[bundleID] = list; }
                if (![list containsObject:plugin]) [list addObject:plugin];
            }
        }

        for (FKAppModel *app in items) {
            NSArray<FKPluginModel *> *linked = _pluginsByBundle[app.bundleID] ?: @[];
            app.pluginIDs = [linked valueForKey:@"pluginID"];
        }
        _apps = items.copy;
    }
    return self;
}

- (NSArray<FKAppModel *> *)allApps {
    return self.apps;
}

- (FKAppModel *)appForBundleID:(NSString *)bundleID {
    if (!bundleID.length) return nil;
    return self.byBundle[bundleID];
}

- (NSArray<FKPluginModel *> *)pluginsForApp:(NSString *)bundleID {
    if (!bundleID.length) return @[];
    return self.pluginsByBundle[bundleID] ?: @[];
}

- (NSDictionary *)injectionSummaryForApp:(NSString *)bundleID {
    NSArray<FKPluginModel *> *linked = [self pluginsForApp:bundleID];
    NSMutableArray<NSString *> *matchedIDs = [NSMutableArray array];
    // 全局规则不指向具体 Bundle，单独由管理器记录是否存在全局覆盖。
    BOOL globalCovered = self.hasGlobalPlugin;
    for (FKPluginModel *plugin in linked) {
        [matchedIDs addObject:plugin.pluginID];
    }
    NSString *state;
    if (globalCovered) state = @"static_global";
    else if (matchedIDs.count > 0) state = @"static_associated";
    else state = @"none";

    return @{
        @"bundle_id": bundleID ?: @"",
        @"static_matched_plugins": matchedIDs.copy,
        @"static_matched_count": @(matchedIDs.count),
        @"global_covered": @(globalCovered),
        /// 本版本仅有静态配置证据；是否真正注入需运行时检查，当前一律记为未验证。
        @"runtime_injection_verified": @NO,
        @"injection_state": state,
        @"note": @"静态 Filter 关联不等于运行时注入成功；未取得进程级注入证据前，不标记为已注入"
    };
}

@end
