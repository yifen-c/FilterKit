#import <Foundation/Foundation.h>

/// 插件只读模型测试（PLG901–912）：检查状态枚举、真实读取来源判定、JSON 字段、
/// 推断来源不冒充清单、Readable 不等于安全或可注入。
@interface FKHelperPluginTests : NSObject

+ (NSArray<NSString *> *)runChecks;
+ (NSUInteger)checkCount;

@end
