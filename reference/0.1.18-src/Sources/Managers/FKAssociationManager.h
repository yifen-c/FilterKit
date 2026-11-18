#import <Foundation/Foundation.h>
#import "FKAppPluginAssociation.h"

NS_ASSUME_NONNULL_BEGIN

/// 关联 / 收藏 / 最近使用管理器：在 App 沙盒内持久化 FilterKit 管理关系。
/// 仅记录管理关系，不写入注入器配置、不代表插件已配置或已运行。
/// 原子写入、启动加载、schema_version、损坏隔离不清历史。
@interface FKAssociationManager : NSObject

/// 当前持久化格式版本。
@property (nonatomic, assign, readonly) NSUInteger schemaVersion;
/// 最近一次持久化错误；无错误为 nil。
@property (nonatomic, copy, readonly, nullable) NSString *lastPersistError;

#pragma mark - 管理关系

/// 全部关联记录（按建立时间升序）。
- (NSArray<FKAppPluginAssociation *> *)allAssociations;
/// 某 App 的关联记录。
- (NSArray<FKAppPluginAssociation *> *)associationsForApp:(NSString *)appBundleID;
/// 某插件关联到的 App 记录。
- (NSArray<FKAppPluginAssociation *> *)associationsForPlugin:(NSString *)pluginID;
/// 查找指定 App ↔ 插件的唯一关联；不存在返回 nil。
- (nullable FKAppPluginAssociation *)associationForApp:(NSString *)appBundleID plugin:(NSString *)pluginID;
/// 是否已存在相同关联。
- (BOOL)hasAssociationForApp:(NSString *)appBundleID plugin:(NSString *)pluginID;

/// 建立管理关系；重复关联返回 nil（不重复创建）。
- (nullable FKAppPluginAssociation *)addAssociationForApp:(NSString *)appBundleID plugin:(NSString *)pluginID;
/// 移除管理关系；返回是否移除成功。
- (BOOL)removeAssociationForApp:(NSString *)appBundleID plugin:(NSString *)pluginID;

#pragma mark - 收藏与最近使用

/// 收藏的 App Bundle ID（无序集合）。
- (NSArray<NSString *> *)favoriteApps;
- (BOOL)isFavoriteApp:(NSString *)appBundleID;
/// 切换收藏状态，返回切换后是否收藏。
- (BOOL)toggleFavoriteApp:(NSString *)appBundleID;

/// 最近使用的 App Bundle ID（最近在前，去重，限量）。
- (NSArray<NSString *> *)recentApps;
/// 记录一次 App 打开/查看；置顶并去重。
- (void)recordRecentApp:(NSString *)appBundleID;

#pragma mark - 导出与状态

/// 关系摘要 JSON（关联 / 收藏 / 最近）。
- (NSDictionary *)JSONDictionary;
/// 持久化状态摘要。
- (NSDictionary *)persistenceStatus;

@end

NS_ASSUME_NONNULL_END
