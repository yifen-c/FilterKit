#import <Foundation/Foundation.h>

/// Filter 规则模型：保留原始 plist 数据，识别失败时记录原因，不丢弃未知字段。
@interface FKFilterModel : NSObject

/// 规则 plist 路径
@property (nonatomic, copy) NSString *filterPath;
/// Bundles 规则（Bundle ID 数组）
@property (nonatomic, copy) NSArray<NSString *> *bundles;
/// Executables 规则（可执行文件名数组）
@property (nonatomic, copy) NSArray<NSString *> *executables;
/// Classes 规则（类名数组）
@property (nonatomic, copy) NSArray<NSString *> *classes;
/// 未归类的其他规则键
@property (nonatomic, copy) NSArray<NSString *> *otherKeys;
/// 原始规则字典（原样保留，供备份与详情查看）
@property (nonatomic, strong) NSDictionary *rawRules;
/// 是否为全局规则（Bundles 含 *）
@property (nonatomic, assign) BOOL global;
/// 解析失败原因；解析成功为空
@property (nonatomic, copy) NSString *parseError;

/// 从扫描结果中的规则字典构建
+ (instancetype)modelWithDictionary:(NSDictionary *)rule filterPath:(NSString *)filterPath;
- (NSDictionary *)JSONDictionary;

@end

/// dpkg 软件包模型
@interface FKPackageModel : NSObject

@property (nonatomic, copy) NSString *packageID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *architecture;
@property (nonatomic, copy) NSString *maintainer;
@property (nonatomic, copy) NSString *descriptionText;
@property (nonatomic, copy) NSString *homepage;
@property (nonatomic, copy) NSString *section;

+ (instancetype)modelWithDictionary:(NSDictionary *)raw;
- (NSDictionary *)JSONDictionary;

@end

/// 插件完整性状态（只读派生，不代表运行时注入结果）
typedef NS_ENUM(NSInteger, FKPluginIntegrity) {
    FKPluginIntegrityUnknown = 0,
    FKPluginIntegrityOK,        /// 结构完整、配置有效
    FKPluginIntegrityWarning,   /// 存在警告（如二进制 MD5 差异、未匹配规则）
    FKPluginIntegrityAbnormal   /// 结构缺失或配置无效
};

/// 插件模型：一个插件可关联多个 App，一个 App 可关联多个插件。
@interface FKPluginModel : NSObject

/// 稳定内部 ID：优先「软件包标识:文件名基名」，避免重名冲突
@property (nonatomic, copy) NSString *pluginID;
/// 插件展示名称
@property (nonatomic, copy) NSString *name;
/// 插件标识（Identifier，可能为空，不允许用名称代替 Bundle ID）
@property (nonatomic, copy) NSString *identifier;
/// 插件版本
@property (nonatomic, copy) NSString *version;
/// 所属 dpkg 软件包标识
@property (nonatomic, copy) NSString *packageID;
/// 候选归属包（多归属记录）
@property (nonatomic, copy) NSArray<NSString *> *packageCandidates;
/// dylib 路径
@property (nonatomic, copy) NSString *dylibPath;
/// Filter plist 路径
@property (nonatomic, copy) NSString *filterPath;
/// 来源：dpkg / manual
@property (nonatomic, copy) NSString *source;
/// 文件配对状态：complete / missing_plist / missing_dylib
@property (nonatomic, copy) NSString *fileStatus;
/// 关联分类（exact_match / global / unmatched_target / unparseable / invalid_configuration / unresolved_non_bundle_rule）
@property (nonatomic, copy) NSString *associationCategory;
/// 关联类型：filter_match / global / unmatched / unknown
@property (nonatomic, copy) NSString *associationType;
/// 已关联 Bundle ID 列表
@property (nonatomic, copy) NSArray<NSString *> *associatedBundleIDs;
/// 未匹配 Bundle ID 列表
@property (nonatomic, copy) NSArray<NSString *> *unmatchedBundleIDs;
/// 已匹配可执行名列表
@property (nonatomic, copy) NSArray<NSString *> *matchedExecutables;
/// 未匹配可执行名列表
@property (nonatomic, copy) NSArray<NSString *> *unmatchedExecutables;
/// 是否全局插件
@property (nonatomic, assign) BOOL isGlobal;
/// 完整性状态枚举
@property (nonatomic, assign) FKPluginIntegrity integrity;
/// 完整性状态文案（完整 / 警告 / 异常 / 未知）
@property (nonatomic, copy) NSString *integrityStatus;
/// 规则模型
@property (nonatomic, strong) FKFilterModel *filter;
/// 重复/冲突标记
@property (nonatomic, copy) NSArray<NSString *> *duplicateFlags;
/// 原始插件字典（保留全部诊断证据）
@property (nonatomic, strong) NSDictionary *raw;

+ (instancetype)modelWithDictionary:(NSDictionary *)raw;
- (NSDictionary *)JSONDictionary;

@end

/// 已安装 App 模型
@interface FKAppModel : NSObject

@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *versionSource;
@property (nonatomic, copy) NSString *buildVersion;
@property (nonatomic, copy) NSString *bundlePath;
/// 可执行文件名（CFBundleExecutable），供 Executables 规则匹配
@property (nonatomic, copy) NSString *executable;
@property (nonatomic, assign) BOOL isSystem;
@property (nonatomic, copy) NSString *iconPath;
@property (nonatomic, copy) NSString *iconSource;
/// 关联插件 ID 列表（由 AppManager 反向索引填充）
@property (nonatomic, copy) NSArray<NSString *> *pluginIDs;

+ (instancetype)modelWithDictionary:(NSDictionary *)raw;
- (NSDictionary *)JSONDictionary;

@end
