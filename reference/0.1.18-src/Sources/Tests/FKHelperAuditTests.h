#import <Foundation/Foundation.h>

/// IPC 审计事件测试（AUD901–910）：默认状态、动作码映射、结果标记、记录计数、
/// 原因码空值，以及审计记录不承载完整配置或文件正文。
@interface FKHelperAuditTests : NSObject

+ (NSArray<NSString *> *)runChecks;
+ (NSUInteger)checkCount;

@end
