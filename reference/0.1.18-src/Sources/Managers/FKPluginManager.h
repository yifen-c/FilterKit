#import <Foundation/Foundation.h>
#import "FKManageModels.h"

/// 插件筛选类别（与插件 Tab 分段控件对应）
typedef NS_ENUM(NSInteger, FKPluginFilter) {
    FKPluginFilterAll = 0,        /// 全部插件
    FKPluginFilterAssociated,    /// 已关联 App
    FKPluginFilterGlobal,         /// 全局插件
    FKPluginFilterUnmatched,      /// 未匹配插件
    FKPluginFilterAbnormal,       /// 有异常插件
    FKPluginFilterWarning         /// 完整性警告
};

/// 插件管理器：从扫描结果构建插件模型并提供只读查询与筛选。
/// 只读查询管理器；不执行安装、卸载、启停等任何写操作（受控操作统一走 FKOperationManager）。
@interface FKPluginManager : NSObject

@property (nonatomic, copy, readonly) NSArray<FKPluginModel *> *allPlugins;

/// 用扫描结果中的插件字典数组构建
- (instancetype)initWithPlugins:(NSArray<NSDictionary *> *)plugins;

/// 按 Bundle ID 反查关联插件
- (NSArray<FKPluginModel *> *)pluginsForBundleID:(NSString *)bundleID;
/// 按稳定插件 ID 查找
- (FKPluginModel *)pluginForID:(NSString *)pluginID;
/// 存在完整性警告的插件
- (NSArray<FKPluginModel *> *)pluginsWithIntegrityWarnings;
/// 全局插件
- (NSArray<FKPluginModel *> *)globalPlugins;
/// 未匹配到 App 的插件
- (NSArray<FKPluginModel *> *)unmatchedPlugins;
/// 已关联至少一个 App 的插件
- (NSArray<FKPluginModel *> *)associatedPlugins;
/// 结构/配置异常的插件
- (NSArray<FKPluginModel *> *)abnormalPlugins;
/// 按类别筛选
- (NSArray<FKPluginModel *> *)pluginsWithFilter:(FKPluginFilter)filter;
/// 按名称 / 标识 / 软件包 / dylib 路径搜索（不重新扫描）
- (NSArray<FKPluginModel *> *)search:(NSString *)query;

@end
