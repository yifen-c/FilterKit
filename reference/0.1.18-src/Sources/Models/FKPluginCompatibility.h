#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 兼容性综合状态（五态，不合并为单一布尔）。
typedef NS_ENUM(NSInteger, FKCompatibilityStatus) {
    FKCompatibilityStatusUnknown = 0,          /// 证据不足，无法判断
    FKCompatibilityStatusCompatible,          /// 各项检查通过
    FKCompatibilityStatusPartiallyCompatible,  /// 部分通过，存在警告或部分未确认
    FKCompatibilityStatusIncompatible,        /// 存在明确不兼容项
    FKCompatibilityStatusUnsupported           /// 当前注入器/格式不支持
};

/// 插件 ↔ 目标 App 的兼容性评估模型。逐项检查保留独立结论；
/// Mach-O 等静态证据仅作参考，不能据此保证插件一定可正常运行。
@interface FKPluginCompatibility : NSObject

@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, copy) NSString *appBundleID;
/// 综合兼容状态。
@property (nonatomic, assign) FKCompatibilityStatus status;
/// 逐项检查：@{ @"key":..., @"status":pass/warn/fail/unknown, @"detail":... }。
@property (nonatomic, copy) NSArray<NSDictionary *> *checks;
/// 已识别的冲突项；无法证明冲突时归入“需要确认”。
@property (nonatomic, copy) NSArray<NSString *> *conflicts;
/// 存疑/警告提示。
@property (nonatomic, copy) NSArray<NSString *> *warnings;

/// 状态枚举 → 展示文案。
+ (NSString *)statusText:(FKCompatibilityStatus)status;
/// 机器可读状态码。
+ (NSString *)statusCode:(FKCompatibilityStatus)status;
+ (nullable instancetype)compatibilityFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
