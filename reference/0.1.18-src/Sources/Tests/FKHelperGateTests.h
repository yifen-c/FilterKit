#import <Foundation/Foundation.h>

/// 操作门禁回归测试（GATE801–810）：Helper 缺失 / 清单未验证 / 身份未知 / 完整性未知 /
/// IPC 不可用 / 对端未验证 / 未知能力拒绝；Mock 不得变为真实连接；全模拟条件不放行；
/// 断开连接后撤销能力。0.1.15 固定只读预演，任何模拟齐备都不获得真实写权限。
@interface FKHelperGateTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
