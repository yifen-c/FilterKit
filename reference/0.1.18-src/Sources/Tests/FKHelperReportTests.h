#import <Foundation/Foundation.h>

/// 统一信任报告 v2 分层测试（REP801–812）：schemaVersion、helper/manifest/capabilities/
/// permissions 分层、只读能力默认值、真实操作锁定与证据可序列化。本套件只校验报告模型与评估结论，
/// 不连接真实 Helper、不产生可信判定。
@interface FKHelperReportTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
