#import "FKPluginManager.h"

@interface FKPluginManager ()
@property (nonatomic, copy) NSArray<FKPluginModel *> *plugins;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FKPluginModel *> *byID;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<FKPluginModel *> *> *byBundle;
@end

@implementation FKPluginManager

- (instancetype)initWithPlugins:(NSArray<NSDictionary *> *)plugins {
    if ((self = [super init])) {
        NSMutableArray<FKPluginModel *> *items = [NSMutableArray array];
        _byID = [NSMutableDictionary dictionary];
        _byBundle = [NSMutableDictionary dictionary];
        for (NSDictionary *raw in plugins ?: @[]) {
            FKPluginModel *model = [FKPluginModel modelWithDictionary:raw];
            if (!model.pluginID.length) continue;
            [items addObject:model];
            _byID[model.pluginID] = model;
            for (NSString *bundleID in model.associatedBundleIDs) {
                if (!bundleID.length) continue;
                NSMutableArray *list = _byBundle[bundleID];
                if (!list) { list = [NSMutableArray array]; _byBundle[bundleID] = list; }
                if (![list containsObject:model]) [list addObject:model];
            }
        }
        _plugins = items.copy;
    }
    return self;
}

- (NSArray<FKPluginModel *> *)allPlugins {
    return self.plugins;
}

- (NSArray<FKPluginModel *> *)pluginsForBundleID:(NSString *)bundleID {
    if (!bundleID.length) return @[];
    return self.byBundle[bundleID] ?: @[];
}

- (FKPluginModel *)pluginForID:(NSString *)pluginID {
    if (!pluginID.length) return nil;
    return self.byID[pluginID];
}

- (NSArray<FKPluginModel *> *)globalPlugins {
    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(FKPluginModel *m, NSDictionary *bindings) {
        (void)bindings; return m.isGlobal;
    }];
    return [self.plugins filteredArrayUsingPredicate:pred];
}

- (NSArray<FKPluginModel *> *)associatedPlugins {
    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(FKPluginModel *m, NSDictionary *bindings) {
        (void)bindings; return m.associatedBundleIDs.count > 0;
    }];
    return [self.plugins filteredArrayUsingPredicate:pred];
}

- (NSArray<FKPluginModel *> *)unmatchedPlugins {
    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(FKPluginModel *m, NSDictionary *bindings) {
        (void)bindings; return m.associatedBundleIDs.count == 0 && !m.isGlobal;
    }];
    return [self.plugins filteredArrayUsingPredicate:pred];
}

- (NSArray<FKPluginModel *> *)pluginsWithIntegrityWarnings {
    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(FKPluginModel *m, NSDictionary *bindings) {
        (void)bindings; return m.integrity == FKPluginIntegrityWarning;
    }];
    return [self.plugins filteredArrayUsingPredicate:pred];
}

- (NSArray<FKPluginModel *> *)abnormalPlugins {
    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(FKPluginModel *m, NSDictionary *bindings) {
        (void)bindings; return m.integrity == FKPluginIntegrityAbnormal;
    }];
    return [self.plugins filteredArrayUsingPredicate:pred];
}

- (NSArray<FKPluginModel *> *)pluginsWithFilter:(FKPluginFilter)filter {
    switch (filter) {
        case FKPluginFilterAssociated: return self.associatedPlugins;
        case FKPluginFilterGlobal: return self.globalPlugins;
        case FKPluginFilterUnmatched: return self.unmatchedPlugins;
        case FKPluginFilterAbnormal: return self.abnormalPlugins;
        case FKPluginFilterWarning: return self.pluginsWithIntegrityWarnings;
        case FKPluginFilterAll:
        default: return self.plugins;
    }
}

- (NSArray<FKPluginModel *> *)search:(NSString *)query {
    NSString *needle = query.lowercaseString;
    if (!needle.length) return self.plugins;
    NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(FKPluginModel *m, NSDictionary *bindings) {
        (void)bindings;
        NSArray<NSString *> *fields = @[m.name ?: @"", m.pluginID ?: @"", m.identifier ?: @"",
                                       m.packageID ?: @"", m.dylibPath ?: @"", m.version ?: @""];
        for (NSString *text in fields) {
            if ([text.lowercaseString containsString:needle]) return YES;
        }
        return NO;
    }];
    return [self.plugins filteredArrayUsingPredicate:pred];
}

@end
