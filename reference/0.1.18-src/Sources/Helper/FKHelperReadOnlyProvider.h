#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 未来 Helper 服务端只读业务接口。0.1.15 只定义受支持数据的读取边界，
/// 不实现真实后台服务，不开放任何写操作；每类数据的来源须在真正接入时明确标注
/// （注入器正式只读接口 / 已授权本地元数据 / FilterKit 自身记录 / 无法验证的推断）。
@protocol FKHelperReadOnlyProvider <NSObject>

/// Helper 基本信息字典。
- (NSDictionary *)helperInfo;

/// Helper 健康状态字典。
- (NSDictionary *)helperHealth;

/// 插件只读列表。
- (NSArray<NSDictionary *> *)pluginList;

/// 按标识查询单个插件信息；不存在返回 nil。
- (nullable NSDictionary *)pluginInfoForIdentifier:(NSString *)pluginID;

/// 配置只读快照。
- (NSDictionary *)configurationSnapshot;

@end

NS_ASSUME_NONNULL_END
