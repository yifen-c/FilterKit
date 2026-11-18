#import <Foundation/Foundation.h>
#import "FKManageModels.h"
#import "FKPluginCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/// 兼容性与冲突检测管理器：基于扫描静态证据做保守评估。
/// 只读评估，不修改配置、不连接 Helper；静态 Mach-O 证据不足以保证运行时兼容，证据不足归 Unknown。
@interface FKCompatibilityManager : NSObject

/// 评估单个插件与目标 App 的兼容性。
/// alreadyAssociated 表示该 App ↔ 插件是否已存在管理关系（用于重复关联提示）。
- (FKPluginCompatibility *)evaluatePlugin:(FKPluginModel *)plugin
                                    forApp:(nullable FKAppModel *)app
                               injectorType:(NSString *)injectorType
                          alreadyAssociated:(BOOL)alreadyAssociated;

/// 跨插件批量冲突检测：重复 dylib、共享 Filter 目标、重复文件标识等。
/// 返回冲突字典数组：@{ @"type":..., @"message":..., @"plugin_ids":... }。
- (NSArray<NSDictionary *> *)detectConflictsAmongPlugins:(NSArray<FKPluginModel *> *)plugins;

@end

NS_ASSUME_NONNULL_END
