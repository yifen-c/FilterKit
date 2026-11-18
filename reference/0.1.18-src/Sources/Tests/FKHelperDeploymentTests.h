#import <Foundation/Foundation.h>

/// Helper 部署可行性与服务名边界测试。
@interface FKHelperDeploymentTests : NSObject
+ (NSArray<NSString *> *)runChecks;
+ (NSUInteger)checkCount;
@end
