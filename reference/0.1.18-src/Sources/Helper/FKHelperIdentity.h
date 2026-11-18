#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// FilterKit 自有 Helper 的稳定逻辑身份。
///
/// 身份不依据设备路径或文件名推测生成：同一个 Helper 在不同设备上应具有相同的逻辑身份。
/// 身份字段匹配不等于身份可信——可信结论仍须经过可信发布清单、签名链与完整性比对独立确认。
@interface FKHelperIdentity : NSObject <NSSecureCoding>

/// Helper 稳定标识（com.filterkit.helper）。
@property (nonatomic, copy) NSString *helperID;
/// 产品标识（FilterKit）。
@property (nonatomic, copy) NSString *productID;
/// 组件标识（FilterKitHelper）。
@property (nonatomic, copy) NSString *componentID;
/// Helper 版本号（0.1.15）。
@property (nonatomic, copy) NSString *version;
/// 构建 ID（FKH-0115）。
@property (nonatomic, copy) NSString *buildID;
/// 协议主版本。
@property (nonatomic, assign) NSInteger protocolMajor;
/// 协议次版本。
@property (nonatomic, assign) NSInteger protocolMinor;

/// 结构完整性：必要字段均非空，且协议主版本 >= 1、次版本 >= 0。
- (BOOL)isStructurallyValid;

/// 与另一身份逐项比较：helperID / productID / componentID / version / buildID /
/// protocolMajor / protocolMinor 全部相等才返回 YES；other 为 nil 返回 NO。
- (BOOL)matchesIdentity:(nullable FKHelperIdentity *)other;

/// 当前 App 内置的预期 Helper 身份（0.1.15 / FKH-0115 / 协议 1.0）。
+ (instancetype)expectedIdentity;

/// 身份字典（用于信任报告、审计记录与协议报文）。
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
