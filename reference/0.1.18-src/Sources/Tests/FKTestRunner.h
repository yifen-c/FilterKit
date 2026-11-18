#import <Foundation/Foundation.h>

/// 最小测试运行器：汇总各纯逻辑套件的自检结果。不依赖 XCTest，
/// 便于 0.3.0 接入完整测试框架前先保护模型 / JSON / 备份 / 准入基础行为。
@interface FKTestRunner : NSObject

/// 运行全部注册套件；返回失败描述数组，空数组表示全部通过。
+ (NSArray<NSString *> *)runAllChecks;

/// 运行全部套件并返回结构化汇总：执行数 / 通过 / 失败 / 跳过与分套件明细。
/// 数字均来自实际执行；未执行的套件不得标记为通过。
+ (NSDictionary *)runSummary;

@end
