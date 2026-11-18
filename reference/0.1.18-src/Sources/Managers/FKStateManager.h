#import <Foundation/Foundation.h>
#import "FKOperationModels.h"

@class FKPluginModel;

/// 插件状态识别：基于 Filter 规则与可获得证据派生状态，每次重新扫描重新判定。
/// 不凭 dylib 文件存在推断已启用；无可靠证据时归 Unknown/Unsupported。
@interface FKStateManager : NSObject

- (instancetype)initWithPlugins:(NSArray<FKPluginModel *> *)plugins injector:(NSString *)injector;

/// 指定插件 ID 的状态快照。
- (FKPluginState *)stateForPluginID:(NSString *)pluginID;
/// 全部插件状态。
- (NSArray<FKPluginState *> *)allStates;

@end
