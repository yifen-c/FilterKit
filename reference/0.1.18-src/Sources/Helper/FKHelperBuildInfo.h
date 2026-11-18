#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 构建环境信息：用于判断当前 App 是否支持该 Helper、Helper 是否支持目标设备、
/// 协议版本是否匹配、是否需要升级 Helper。本模型只记录构建元信息，不构成可信结论。
@interface FKHelperBuildInfo : NSObject <NSSecureCoding>

/// 产品版本号。
@property (nonatomic, copy) NSString *productVersion;
/// 构建编号。
@property (nonatomic, copy) NSString *buildNumber;
/// 编译 SDK 版本。
@property (nonatomic, copy) NSString *sdkVersion;
/// 最低支持系统版本。
@property (nonatomic, copy) NSString *minimumOSVersion;
/// 支持架构集合（arm64 / arm64e）。
@property (nonatomic, copy) NSArray<NSString *> *architectures;
/// 源码修订标识（revision / commit）。
@property (nonatomic, copy) NSString *sourceRevision;

/// 构建信息字典（可独立导出）。
- (NSDictionary *)JSONDictionary;

/// 由字典构造；非字典输入返回 nil。
+ (nullable instancetype)buildInfoFromDictionary:(nullable NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
