#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 管理关系来源：用户在 FilterKit 内手动建立的关联（区别于扫描器的静态 Filter 匹配）。
/// 0.1.6 只记录管理关系，不代表注入器已配置、更不代表插件已运行。
typedef NSString *FKAssociationSource NS_STRING_ENUM;
/// 用户在 App 详情内手动添加插件形成的管理关系。
static FKAssociationSource const FKAssociationSourceManual = @"manual";
/// 由扫描静态 Filter 匹配回写（0.1.6 不写入该来源，预留后续兼容）。
static FKAssociationSource const FKAssociationSourceScanner = @"scanner_match";

/// 管理关系状态：关联记录存在即 Associated；Configured / Active 由详情层结合
/// 注入器配置证据与运行时证据派生，不存储在关联记录上。
typedef NSString *FKAssociationStatus NS_STRING_ENUM;
static FKAssociationStatus const FKAssociationStatusAssociated = @"associated";

/// App ↔ 插件管理关系模型：FKAppModel 1:N，FKPluginModel N:1。
/// 仅描述 FilterKit 内记录的管理关系，与注入器真实配置、运行时加载状态相互独立。
@interface FKAppPluginAssociation : NSObject

/// 关联记录稳定 ID。
@property (nonatomic, copy) NSString *associationID;
/// 目标 App Bundle ID。
@property (nonatomic, copy) NSString *appBundleID;
/// 目标插件稳定 ID。
@property (nonatomic, copy) NSString *pluginID;
/// 建立时间。
@property (nonatomic, copy) NSDate *createdAt;
/// 最近更新时间。
@property (nonatomic, copy) NSDate *updatedAt;
/// 来源（manual / scanner_match）。
@property (nonatomic, copy) FKAssociationSource source;
/// 管理关系状态（associated）。
@property (nonatomic, copy) FKAssociationStatus status;

/// 从持久化字典还原；字段非法返回 nil。
+ (nullable instancetype)associationFromDictionary:(NSDictionary *)dict;
/// 导出可持久化的字典。
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
