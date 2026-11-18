#import <Foundation/Foundation.h>

/// JSON 兼容最小测试：核对非法 / 空输入被安全忽略，模型与证据不抛出异常、不产生越界字段。
@interface FKJSONTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数（与 runChecks 中的检查项一一对应）。
+ (NSUInteger)checkCount;

@end
