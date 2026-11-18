#import <Foundation/Foundation.h>

/// Helper 信任链分层测试：发现、身份、签名、完整性、IPC 模型与权限预评估。
/// 模拟数据仅用于核对本地判定逻辑；模拟通过不代表真机已获得写权限。
@interface FKHelperTrustTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数（与 runChecks 中的检查项一一对应）。
+ (NSUInteger)checkCount;

@end
