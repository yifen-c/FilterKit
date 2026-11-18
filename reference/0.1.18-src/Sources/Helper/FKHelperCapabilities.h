#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// v1 只读能力枚举。
typedef NS_ENUM(NSInteger, FKHelperCapability) {
    FKHelperCapabilityHelperInfo = 0,
    FKHelperCapabilityHelperHealth,
    FKHelperCapabilityCapabilityList,
    FKHelperCapabilityPluginList,
    FKHelperCapabilityPluginInspect,
    FKHelperCapabilityConfigurationInspect
};

/// v1 只读能力模型。0.1.15 只登记只读能力；写操作能力不注册、不执行。
/// 能力存在不等于身份或签名已通过；真实权限仍须经完整信任链与门禁评估。
@interface FKHelperCapabilities : NSObject

/// 能力键集合。
@property (nonatomic, copy) NSSet<NSString *> *supportedCapabilities;

/// 以给定能力集合构造。
+ (instancetype)capabilitiesWithSet:(NSSet<NSString *> *)capabilities;

/// 某能力是否被支持（须在只读白名单内且已登记）。
- (BOOL)supportsCapability:(NSString *)capability;

/// 登记的能力是否全部属于只读白名单（不含任何写能力或未知能力）。
- (BOOL)containsOnlyReadOnlyCapabilities;

/// v1 只读能力白名单。
+ (NSSet<NSString *> *)readOnlyWhitelist;

/// 枚举能力对应的字符串键。
+ (NSString *)keyForCapability:(FKHelperCapability)capability;

/// 明确禁止进入可执行白名单的写操作能力。
+ (NSSet<NSString *> *)writeCapabilityBlacklist;

- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
