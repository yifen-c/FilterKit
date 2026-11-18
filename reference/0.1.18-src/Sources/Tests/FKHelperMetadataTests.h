#import <Foundation/Foundation.h>

/// Helper 发布元数据与构建信息测试（HFM801–806）：字段完整性、JSON 往返、缺失识别，
/// 以及"元数据完整不等于身份可信"的边界核对。
@interface FKHelperMetadataTests : NSObject

/// 返回失败描述数组；空数组表示全部通过。
+ (NSArray<NSString *> *)runChecks;
/// 本套件断言用例数。
+ (NSUInteger)checkCount;

@end
