#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 注入器配置快照：操作前保存目标 App 与插件对应的原始配置上下文，用于前后差异比对与受控回滚评估。
/// 与插件文件备份相互独立；本模型只记录配置引用与快照，不复制、不覆盖原配置文件。
@interface FKConfigurationBackup : NSObject

/// 备份唯一标识。
@property (nonatomic, copy) NSString *backupID;
/// 识别到的注入器类型（如 libhooker / ellekit / substitute）。
@property (nonatomic, copy, nullable) NSString *injectorType;
/// 目标 App Bundle ID；全局插件为空。
@property (nonatomic, copy, nullable) NSString *targetAppBundleID;
/// 插件标识。
@property (nonatomic, copy) NSString *pluginID;
/// 原始配置快照（只读上下文；共享配置包含全部相关插件字段，不仅单条记录）。
@property (nonatomic, copy) NSDictionary *originalConfiguration;
/// 配置快照摘要哈希（由备份管理器计算后写入）。
@property (nonatomic, copy, nullable) NSString *configurationHash;
/// 备份时间。
@property (nonatomic, copy) NSDate *timestamp;
/// 关联操作事务 ID。
@property (nonatomic, copy, nullable) NSString *operationID;
/// 操作类型文本（enable / disable / restore）。
@property (nonatomic, copy, nullable) NSString *operationText;

+ (instancetype)backupWithPluginID:(NSString *)pluginID
                       injectorType:(nullable NSString *)injectorType
                 targetAppBundleID:(nullable NSString *)appBundleID
                       operationID:(nullable NSString *)operationID
                originalConfiguration:(NSDictionary *)configuration;

+ (nullable instancetype)backupFromDictionary:(nullable NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
