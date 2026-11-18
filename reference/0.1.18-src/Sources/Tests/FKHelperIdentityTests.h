#import <Foundation/Foundation.h>

/// Helper 身份模型测试（HFA801–808）：固定身份字段、结构校验与逐项比较。
/// 模拟身份仅核对本地模型逻辑；身份字段匹配不等于身份可信。
@interface FKHelperIdentityTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
