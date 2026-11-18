#import <Foundation/Foundation.h>

/// 文件完整性测试（INT801–809）：流式 SHA-256、缺失/无可信锚点/不匹配/匹配判定，
/// 以及签名状态与完整性状态分离。摘要计算失败不得当作空摘要比对。
@interface FKHelperIntegrityTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
