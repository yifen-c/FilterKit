#import "FKStateManager.h"
#import "FKManageModels.h"

@interface FKStateManager ()
@property (nonatomic, copy) NSArray<FKPluginModel *> *plugins;
@property (nonatomic, copy) NSDictionary<NSString *, FKPluginModel *> *byID;
@property (nonatomic, copy) NSString *injector;
@end

@implementation FKStateManager

- (instancetype)initWithPlugins:(NSArray<FKPluginModel *> *)plugins injector:(NSString *)injector {
    if ((self = [super init])) {
        _plugins = plugins ?: @[];
        _injector = injector ?: @"";
        NSMutableDictionary<NSString *, FKPluginModel *> *index = [NSMutableDictionary dictionary];
        for (FKPluginModel *model in _plugins) {
            if (model.pluginID.length) index[model.pluginID] = model;
        }
        _byID = index.copy;
    }
    return self;
}

- (FKPluginState *)stateForPluginID:(NSString *)pluginID {
    FKPluginModel *model = pluginID.length ? self.byID[pluginID] : nil;
    if (!model) return [self unknownStateForPluginID:pluginID];
    return [self stateForModel:model];
}

- (NSArray<FKPluginState *> *)allStates {
    NSMutableArray<FKPluginState *> *states = [NSMutableArray array];
    for (FKPluginModel *model in self.plugins) [states addObject:[self stateForModel:model]];
    return states.copy;
}

- (FKPluginState *)unknownStateForPluginID:(NSString *)pluginID {
    FKPluginState *state = [FKPluginState new];
    state.pluginID = pluginID ?: @"";
    state.status = FKPluginStatusUnknown;
    state.evidence = @"未在扫描结果中找到该插件";
    state.lastChecked = [NSDate date];
    state.injector = self.injector;
    state.supported = NO;
    state.unsupportedReason = @"未识别到受支持的管理接口";
    state.associationStatus = FKPluginAssociationStateUnknown;
    state.configurationStatus = FKConfigurationStatusUnknown;
    state.runtimeStatus = FKRuntimeStatusUnknown;
    state.backupStatus = FKPluginBackupStatusUnknown;
    return state;
}

- (FKPluginState *)stateForModel:(FKPluginModel *)model {
    FKPluginState *state = [FKPluginState new];
    state.pluginID = model.pluginID;
    state.lastChecked = [NSDate date];
    state.injector = self.injector;
    state.appBundleID = model.associatedBundleIDs.firstObject;

    // 当前版本尚未接入身份已验证的管理 Helper，整体不开放受控启停。
    state.supported = NO;
    state.unsupportedReason = @"未识别到受支持的管理接口；真实启停待 RootHelper 身份、签名与协议验证后开放";

    NSDictionary *rule = model.filter.rawRules;
    NSNumber *enabled = rule[@"enabled"];

    // 关联状态：仅描述 FilterKit 内的管理关系，独立于配置与运行时。
    state.associationStatus = model.associatedBundleIDs.count > 0
        ? FKPluginAssociationStateAssociated : FKPluginAssociationStateNotAssociated;

    // 配置状态：依据静态 Filter 规则证据派生；无证据归 Unknown，不凭文件存在推断启用。
    if ([enabled isEqualToNumber:@NO]) {
        state.configurationStatus = FKConfigurationStatusDisabled;
    } else if ([enabled isEqualToNumber:@YES]) {
        state.configurationStatus = FKConfigurationStatusEnabled;
    } else {
        state.configurationStatus = FKConfigurationStatusUnknown;
    }

    // 运行状态：0.1.15 无进程加载证据通道，恒归 Unknown，不由配置状态推断。
    state.runtimeStatus = FKRuntimeStatusUnknown;
    state.backupStatus = FKPluginBackupStatusUnknown;

    if ([enabled isEqualToNumber:@NO]) {
        state.status = FKPluginStatusDisabled;
        state.evidence = @"Filter 规则 enabled=false（静态证据，未验证运行时）";
    } else if ([enabled isEqualToNumber:@YES] && model.associatedBundleIDs.count > 0) {
        state.status = FKPluginStatusPartiallyEnabled;
        state.evidence = @"Filter 规则 enabled=true 且已关联 App（静态配置，运行时注入未验证）";
    } else {
        state.status = FKPluginStatusUnknown;
        state.evidence = @"缺少可判定启停状态的可靠证据";
        if (!state.supported) state.status = FKPluginStatusUnsupported;
    }
    return state;
}

@end
