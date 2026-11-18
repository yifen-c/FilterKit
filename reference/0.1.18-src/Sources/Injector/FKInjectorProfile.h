#import <Foundation/Foundation.h>

/// 注入器能力画像。能力分两类：解析/定向/全局注入由指纹与规则证据判断；
/// 启停能力必须经过真实验证才置真，不能因 Filter 或 dylib 存在推断支持安全启停。
@interface FKInjectorProfile : NSObject

/// 注入器标识（libhooker / ellekit / substrate / substitute / unknown）
@property (nonatomic, copy) NSString *injectorID;
/// 展示名称
@property (nonatomic, copy) NSString *name;
/// 基线版本（注册表内置可为空，运行时版本由模型补充）
@property (nonatomic, copy) NSString *version;

/// 是否具备 Filter 规则解析能力
@property (nonatomic, assign) BOOL filterParsing;
/// 是否支持按 App 定向注入
@property (nonatomic, assign) BOOL appTargeting;
/// 是否支持全局注入
@property (nonatomic, assign) BOOL globalInjection;
/// 是否存在已验证的插件启用机制（未验证恒为 NO）
@property (nonatomic, assign) BOOL pluginEnable;
/// 是否存在已验证的插件停用机制（未验证恒为 NO）
@property (nonatomic, assign) BOOL pluginDisable;

/// 管理方式（unknown / filter_file / managed_daemon / none）
@property (nonatomic, copy) NSString *managementMethod;
/// 启停机制是否经过真实验证；未验证前不据此开放操作
@property (nonatomic, assign) BOOL managementVerified;

+ (instancetype)profileFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

@end
