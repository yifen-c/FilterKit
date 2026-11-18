#import <Foundation/Foundation.h>

/// 只读能力模型与能力准入评估测试（CAP801–809）：白名单边界、写能力/未知能力拒绝、
/// 纯只读集合判定，以及评估器在信任链未验证时拒绝、模拟齐备仅用于验证正向逻辑。
@interface FKHelperCapabilityTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
