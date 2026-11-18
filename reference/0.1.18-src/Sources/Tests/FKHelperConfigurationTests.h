#import <Foundation/Foundation.h>

/// 配置只读快照测试（CFG901–910）：校验状态枚举、只读接口确认判定、记录计数、
/// 来源区分，以及无摘要时不臆造、模型不含写操作。
@interface FKHelperConfigurationTests : NSObject

+ (NSArray<NSString *> *)runChecks;
+ (NSUInteger)checkCount;

@end
