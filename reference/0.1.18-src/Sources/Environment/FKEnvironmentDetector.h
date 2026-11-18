#import <Foundation/Foundation.h>
#import "FKEnvironmentModel.h"

/// 环境探测器：把扫描器产出的 environment / filesystem 字典派生为带证据来源的结构化模型。
/// 只做只读探测与整理，不修改系统文件；结论由证据保守派生。
@interface FKEnvironmentDetector : NSObject

/// 依据扫描环境字典构建环境模型。
/// @param environment 扫描器 environment 字典；可空
/// @param filesystem 扫描器 filesystem 字典（含注入器等补充证据）；可空
+ (FKEnvironmentModel *)modelFromEnvironment:(NSDictionary *)environment
                                 filesystem:(NSDictionary *)filesystem;

@end
