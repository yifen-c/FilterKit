#import <Foundation/Foundation.h>
#import "FKManageModels.h"
#import "FKPluginManager.h"

/// App 管理器：聚合 App 信息、反向关联插件，并生成 App 级诊断摘要。
/// 明确区分「静态 Filter 匹配」与「运行时注入成功」；无运行时证据时不把静态匹配报为已注入。
@interface FKAppManager : NSObject

@property (nonatomic, copy, readonly) NSArray<FKAppModel *> *allApps;

- (instancetype)initWithApps:(NSArray<NSDictionary *> *)apps plugins:(NSArray<FKPluginModel *> *)plugins;

- (FKAppModel *)appForBundleID:(NSString *)bundleID;
/// 关联到该 App 的插件（静态 Filter 匹配结果）
- (NSArray<FKPluginModel *> *)pluginsForApp:(NSString *)bundleID;
/// App 级别注入诊断摘要
- (NSDictionary *)injectionSummaryForApp:(NSString *)bundleID;

@end
