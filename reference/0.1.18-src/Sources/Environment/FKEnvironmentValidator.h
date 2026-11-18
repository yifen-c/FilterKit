#import <Foundation/Foundation.h>
#import "FKEnvironmentCompatibility.h"

/// 环境证据充分性校验：依据可核对证据保守派生兼容性结论。
/// 路径不可读只归 Partial/Unknown，不直接认定环境不兼容；证据不足不臆断 Passed。
@interface FKEnvironmentValidator : NSObject

/// 依据各项证据派生兼容性结论。
/// @param typeCode 越狱类型码（roothide / rootless / unknown）
/// @param jbrootDetected 是否定位到 JBROOT 路径
/// @param jbrootReadable JBROOT 是否可读；不可读可能是沙盒权限或路径映射差异
/// @param injectorIdentified 是否识别到注入器
/// @param supported 当前环境是否在支持范围
/// @param reasons 输出原因列表，调用方传入可变数组
+ (FKCompatibilityStatus)evaluateWithTypeCode:(NSString *)typeCode
                                jbrootDetected:(BOOL)jbrootDetected
                                 jbrootReadable:(BOOL)jbrootReadable
                            injectorIdentified:(BOOL)injectorIdentified
                                     supported:(BOOL)supported
                                       reasons:(NSMutableArray<NSString *> *)reasons;

@end
