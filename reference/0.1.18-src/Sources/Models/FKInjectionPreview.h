#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 预览综合结果：可继续保存管理关系 / 存在警告但可继续 / 被安全门禁阻断。
typedef NSString *FKPreviewResult NS_STRING_ENUM;
static FKPreviewResult const FKPreviewResultReady = @"preview_ready";
static FKPreviewResult const FKPreviewResultWarnings = @"preview_warnings";
static FKPreviewResult const FKPreviewResultBlocked = @"preview_blocked";

/// 单条检查项状态：pass 通过 / warn 警告 / fail 未通过 / unknown 证据不足。
typedef NSString *FKCheckStatus NS_STRING_ENUM;
static FKCheckStatus const FKCheckStatusPass = @"pass";
static FKCheckStatus const FKCheckStatusWarn = @"warn";
static FKCheckStatus const FKCheckStatusFail = @"fail";
static FKCheckStatus const FKCheckStatusUnknown = @"unknown";

/// 配置预览模型：记录一次「App ↔ 插件」准备建立关联前的静态检查快照。
/// 0.1.6 恒为 previewOnly，systemModified 恒为 NO：只生成预览，不写注入器配置、不启停插件。
@interface FKInjectionPreview : NSObject

/// 预览记录 ID。
@property (nonatomic, copy) NSString *previewID;
/// 目标 App Bundle ID。
@property (nonatomic, copy) NSString *appBundleID;
/// 目标插件 ID。
@property (nonatomic, copy) NSString *pluginID;
/// 候选 dylib 路径（来自扫描证据，可能为空）。
@property (nonatomic, copy) NSString *dylibPath;
/// 当前识别到的注入器类型。
@property (nonatomic, copy) NSString *injectorType;
/// 五组检查项：App / Plugin / Mach-O / Injector / Security。
/// 每项为 @{ @"group":..., @"key":..., @"status":FKCheckStatus, @"detail":... }。
@property (nonatomic, copy) NSArray<NSDictionary *> *checks;
/// 潜在冲突与存疑提示；无法证明冲突时标“需要确认”，不直接判冲突。
@property (nonatomic, copy) NSArray<NSString *> *warnings;
/// 生成时间。
@property (nonatomic, copy) NSDate *createdAt;
/// 是否仅预览（0.1.6 恒 YES）。
@property (nonatomic, assign) BOOL previewOnly;
/// 是否修改了系统配置（0.1.6 恒 NO）。
@property (nonatomic, assign) BOOL systemModified;
/// 综合预览结果。
@property (nonatomic, copy) FKPreviewResult result;

/// 从持久化字典还原；字段非法返回 nil。
+ (nullable instancetype)previewFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
