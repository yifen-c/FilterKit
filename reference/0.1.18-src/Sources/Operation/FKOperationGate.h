#import <Foundation/Foundation.h>
#import "FKOperationModels.h"

@class FKPluginModel, FKHelperTrustReport, FKOperationEligibility, FKOperationPolicy;

NS_ASSUME_NONNULL_BEGIN

/// 操作准入闸门。默认 PreviewOnly；不通过普通 UI 设置直接切换为 Enabled。
typedef NS_ENUM(NSInteger, FKOperationGate) {
    FKOperationGatePreviewOnly = 0,  /// 只读预演：可查看检查项与影响，不执行真实操作
    FKOperationGateBlocked,           /// 门槛不满足，禁止真实操作
    FKOperationGateEnabled            /// 全部门槛通过，允许指定操作（0.1.2 不进入此态）
};

/// 单项预检查结论。
typedef NS_ENUM(NSInteger, FKPreflightStatus) {
    FKPreflightStatusPassed = 0,   /// 通过
    FKPreflightStatusWarning,      /// 警告，可继续预演但需留意
    FKPreflightStatusFailed,      /// 不满足，禁止操作
    FKPreflightStatusUnknown,      /// 证据不足，无法判定
    FKPreflightStatusBlocked       /// 被安全门槛阻断
};

/// 单项操作检查结果。
@interface FKOperationCheck : NSObject

/// 检查项标识（identity / path / ownership / injector / format / method / backup / impact / helper_trust）
@property (nonatomic, copy) NSString *checkID;
/// 展示标题
@property (nonatomic, copy) NSString *title;
/// 结论说明或未通过原因
@property (nonatomic, copy) NSString *reason;
/// 检查结论
@property (nonatomic, assign) FKPreflightStatus status;

+ (instancetype)checkWithID:(NSString *)checkID title:(NSString *)title reason:(NSString *)reason status:(FKPreflightStatus)status;
- (NSDictionary *)JSONDictionary;

@end

/// 操作预检查：汇总 Helper 安全门槛与插件操作门槛，只输出准入判断，不直接执行操作。
@interface FKOperationPreflight : NSObject

/// 生成指定插件的全部检查项。
+ (NSArray<FKOperationCheck *> *)checksForPlugin:(FKPluginModel *)model
                                        injector:(NSString *)injector
                                    helperReport:(nullable FKHelperTrustReport *)helperReport
                                  backupAvailable:(BOOL)backupAvailable;

/// 是否具备操作资格：不存在 Failed / Blocked 项。
+ (BOOL)isOperationEligible:(NSArray<FKOperationCheck *> *)checks;

/// 依据检查项综合判定准入闸门。
+ (FKOperationGate)gateForChecks:(NSArray<FKOperationCheck *> *)checks;

/// 高层准入评估：汇总环境、注入器兼容性、Helper 信任、备份与授权条件，输出结构化结论。
/// 结论动态计算；0.1.4 固定只读预演，不允许 UI 直接绕过闸门。
+ (FKOperationEligibility *)eligibilityForPlugin:(FKPluginModel *)plugin
                                        operation:(FKOperationType)operation
                                   environmentOK:(BOOL)environmentOK
                                injectorCompatible:(BOOL)injectorCompatible
                                     helperReport:(nullable FKHelperTrustReport *)helperReport
                                   backupAvailable:(BOOL)backupAvailable
                                    userAuthorized:(BOOL)userAuthorized;

/// 0.1.15 完整准入评估：覆盖插件身份、App 身份、Helper 身份/签名/IPC/协议、用户授权、
/// Injector、目标配置可读、配置范围、备份、备份校验、兼容性与审计可写；输出决策与原因码。
+ (FKOperationEligibility *)evaluateOperationForPlugin:(FKPluginModel *)plugin
                                            appBundleID:(nullable NSString *)appBundleID
                                             operation:(FKOperationType)operation
                                         environmentOK:(BOOL)environmentOK
                                      injectorCompatible:(BOOL)injectorCompatible
                                              injector:(nullable NSString *)injector
                                          helperReport:(nullable FKHelperTrustReport *)helperReport
                                       backupAvailable:(BOOL)backupAvailable
                                          backupValid:(BOOL)backupValid
                                            scopeClear:(BOOL)scopeClear
                                         auditWritable:(BOOL)auditWritable
                                       userAuthorized:(BOOL)userAuthorized;

/// 依据检查项与策略综合判定准入决策。
+ (FKOperationDecision)decisionForChecks:(NSArray<FKOperationCheck *> *)checks
                                   policy:(FKOperationPolicy *)policy;

/// 检查项标识到机器可读拒绝原因码的映射；未阻断的检查项返回 nil。
+ (nullable NSString *)reasonCodeForCheckID:(NSString *)checkID status:(FKPreflightStatus)status;

/// 闸门文案。
+ (NSString *)gateText:(FKOperationGate)gate;

@end

NS_ASSUME_NONNULL_END
