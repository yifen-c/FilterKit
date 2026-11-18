#import <Foundation/Foundation.h>
#import "FKInjectorModel.h"

/// 注入器探测器：把扫描器 environment.injector 字典整理为注入器识别模型。
/// 只做证据整理，不根据 dylib/Filter 存在推断插件已启用。
@interface FKInjectorDetector : NSObject

/// 依据扫描注入器字典构建模型；字典为空时返回未识别模型。
+ (FKInjectorModel *)modelFromDictionary:(NSDictionary *)injectorDictionary;

@end
