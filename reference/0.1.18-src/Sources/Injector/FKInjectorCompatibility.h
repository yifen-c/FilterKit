#import <Foundation/Foundation.h>

/// 插件在当前注入器下的兼容性结论。兼容性只判断规则与注入能否被处理，
/// 不代表具备已验证的安全启停能力。
typedef NS_ENUM(NSInteger, FKInjectorCompatibilityStatus) {
    FKInjectorCompatibilityStatusUnknown = 0,   /// 证据不足，无法判定
    FKInjectorCompatibilityStatusCompatible,   /// 规则与注入方式受支持
    FKInjectorCompatibilityStatusPartial,      /// 部分能力受限
    FKInjectorCompatibilityStatusIncompatible  /// 明确不受支持
};

@interface FKInjectorCompatibility : NSObject

/// 插件标识
@property (nonatomic, copy) NSString *pluginID;
/// 注入器标识
@property (nonatomic, copy) NSString *injectorID;
/// 兼容性结论
@property (nonatomic, assign) FKInjectorCompatibilityStatus status;
/// 原因列表
@property (nonatomic, copy) NSArray<NSString *> *reasons;

+ (NSString *)statusCode:(FKInjectorCompatibilityStatus)status;
- (NSDictionary *)JSONDictionary;

@end
