#import <Foundation/Foundation.h>
#import "FKInjectorProfile.h"
#import "FKInjectorModel.h"
#import "FKInjectorCompatibility.h"

@class FKPluginModel;

/// 注入器注册表：维护已知注入器的能力画像，并提供插件兼容性查询。
/// 启停能力在真实验证前保持未验证；注册表不把 Filter/dylib 存在推断为已启用。
@interface FKInjectorRegistry : NSObject

/// 查询注入器画像；未登记注入器返回 nil。
- (FKInjectorProfile *)profileForInjector:(NSString *)injectorID;

/// 依据注入器画像与插件规则，评估兼容性。
/// @param plugin 插件模型
/// @param injector 识别到的注入器模型；未识别传入 nil
- (FKInjectorCompatibility *)compatibilityForPlugin:(FKPluginModel *)plugin
                                            injector:(FKInjectorModel *)injector;

@end
