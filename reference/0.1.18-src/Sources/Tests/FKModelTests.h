#import <Foundation/Foundation.h>

/// 模型序列化最小测试：核对模型字典构建与 JSON 往返关键字段不丢失。
@interface FKModelTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数（与 runChecks 中的检查项一一对应）。
+ (NSUInteger)checkCount;

@end
