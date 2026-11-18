#import <Foundation/Foundation.h>

/// 服务发现与连接状态测试（SRV901–908）：无候选、系统工具候选、标识不符、元数据缺失、
/// 形态完整仅记 Found、端点 JSON 字段、批量顺序，以及连接就绪 / 终态判定。
@interface FKHelperDiscoveryTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
