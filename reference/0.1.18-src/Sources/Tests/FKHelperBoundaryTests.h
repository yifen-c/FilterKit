#import <Foundation/Foundation.h>

/// 0.1.15 协议边界回归：Mock 隔离、响应关联、只读能力、结构化 Provider 回执。
@interface FKHelperBoundaryTests : NSObject
+ (NSArray<NSString *> *)runChecks;
+ (NSUInteger)checkCount;
@end
