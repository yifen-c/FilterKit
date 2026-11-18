#import <Foundation/Foundation.h>

/// 注入器识别结果：保留类型、版本、归属包与证据级别。
/// 裸 dylib 或 Filter 存在只作为存在性证据，不推断版本或已启用。
@interface FKInjectorModel : NSObject

/// 注入器标识（libhooker / ellekit / substrate / substitute / unknown）
@property (nonatomic, copy) NSString *injectorID;
/// 展示名称
@property (nonatomic, copy) NSString *name;
/// 识别到的版本；未取得为空
@property (nonatomic, copy) NSString *version;
/// 归属软件包标识；无可追溯归属为空
@property (nonatomic, copy) NSString *packageID;
/// 版本来源（dpkg_status / framework_info_plist / fingerprint / none）
@property (nonatomic, copy) NSString *versionSource;
/// 证据级别（verified / partial / unknown）
@property (nonatomic, copy) NSString *evidenceLevel;
/// 是否识别到注入器
@property (nonatomic, assign) BOOL detected;
/// 原始识别字典
@property (nonatomic, strong) NSDictionary *raw;

+ (instancetype)modelFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

@end
