#import <Foundation/Foundation.h>

/// 备份清单最小测试：核对文件条目与清单的字典往返不丢失大小、摘要与路径。
@interface FKBackupTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数（与 runChecks 中的检查项一一对应）。
+ (NSUInteger)checkCount;

@end
