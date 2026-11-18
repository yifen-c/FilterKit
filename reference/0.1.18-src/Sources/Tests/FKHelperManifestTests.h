#import <Foundation/Foundation.h>

/// 可信发布清单测试（HMF801–812）：清单解析、结构与身份匹配、摘要校验、
/// 签名/Key ID/通道保守判定。未建立可信锚点前任何输入都不得放行。
@interface FKHelperManifestTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
