#import <Foundation/Foundation.h>

/// 环境兼容性结论。证据不足归 Unknown/Partial；路径不可读不直接判 Failed；
/// 仅当取得明确不兼容证据时才判 Failed，当前环境不在支持范围判 Unsupported。
typedef NS_ENUM(NSInteger, FKCompatibilityStatus) {
    FKCompatibilityStatusUnknown = 0,      /// 证据不足，无法判定
    FKCompatibilityStatusPassed,          /// 必要目录与注入器均取得证据
    FKCompatibilityStatusPartial,         /// 环境已识别，但部分目录 / 注入器证据不足
    FKCompatibilityStatusFailed,          /// 明确检测到不兼容条件
    FKCompatibilityStatusUnsupported      /// 当前架构 / 系统不在支持范围
};

/// 兼容旧代码引用的类型别名，语义与 FKCompatibilityStatus 一致。
typedef FKCompatibilityStatus FKEnvironmentCompatibility;

/// 兼容旧代码的枚举值别名。
#define FKEnvironmentCompatibilityUnknown     FKCompatibilityStatusUnknown
#define FKEnvironmentCompatibilityPassed     FKCompatibilityStatusPassed
#define FKEnvironmentCompatibilityPartial    FKCompatibilityStatusPartial
#define FKEnvironmentCompatibilityFailed     FKCompatibilityStatusFailed
#define FKEnvironmentCompatibilityUnsupported FKCompatibilityStatusUnsupported

/// 机器可读状态码（passed / partial / failed / unknown / unsupported）。
NSString *FKCompatibilityCode(FKCompatibilityStatus status);
/// 面向界面的状态文案。
NSString *FKCompatibilityText(FKCompatibilityStatus status);
