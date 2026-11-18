#import <Foundation/Foundation.h>
#import "FKManageModels.h"
#import "FKInjectionPreview.h"
#import "FKPluginCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/// 配置预览管理器：汇总 App / Plugin / Mach-O / Injector / Security 五组检查，
/// 生成只读 FKInjectionPreview 并持久化历史预览。0.1.6 不写注入器配置、不启停、不连 Helper。
@interface FKInjectionPreviewManager : NSObject

@property (nonatomic, assign, readonly) NSUInteger schemaVersion;
@property (nonatomic, copy, readonly, nullable) NSString *lastPersistError;

/// 基于扫描模型、兼容性结论与 Helper 信任快照生成一次预览（不持久化，需调用方保存）。
- (FKInjectionPreview *)buildPreviewForApp:(nullable FKAppModel *)app
                                     plugin:(FKPluginModel *)plugin
                                injectorType:(NSString *)injectorType
                             compatibility:(nullable FKPluginCompatibility *)compatibility
                                 trustReport:(nullable NSDictionary *)trustReport;

/// 保存一条预览记录并持久化。
- (void)savePreview:(FKInjectionPreview *)preview;
/// 全部历史预览（时间倒序，最近在前）。
- (NSArray<FKInjectionPreview *> *)allPreviews;
- (NSArray<FKInjectionPreview *> *)previewsForApp:(NSString *)appBundleID;
- (NSArray<FKInjectionPreview *> *)previewsForPlugin:(NSString *)pluginID;

- (NSDictionary *)JSONDictionary;
- (NSDictionary *)persistenceStatus;

@end

NS_ASSUME_NONNULL_END
