#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 插件可识别状态。状态必须有证据来源；无可靠证据时归 Unknown，不得凭文件存在推断为已启用。
typedef NS_ENUM(NSInteger, FKPluginStatus) {
    FKPluginStatusUnknown = 0,          /// 无法确定
    FKPluginStatusEnabled,              /// 已启用，有明确配置证据
    FKPluginStatusDisabled,             /// 已停用，有明确配置证据
    FKPluginStatusPartiallyEnabled,     /// 部分配置生效
    FKPluginStatusPending,              /// 操作正在执行
    FKPluginStatusFailed,               /// 最近一次操作失败
    FKPluginStatusUnsupported            /// 当前注入器或插件格式不支持状态管理
};

/// 受控操作类型。Helper 仅接受白名单枚举，不接收任意命令字符串。
typedef NS_ENUM(NSInteger, FKOperationType) {
    FKOperationTypeEnable = 0,
    FKOperationTypeDisable,
    FKOperationTypeValidate,
    FKOperationTypeRestore
};

/// 关联状态：管理关系层面，与注入器是否真实配置、进程是否已加载相互独立。
/// 与既有 FKAppPluginAssociation.h 的 FKAssociationStatus（NSString 字符串枚举）区分，避免类型重定义。
typedef NS_ENUM(NSInteger, FKPluginAssociationState) {
    FKPluginAssociationStateUnknown = 0,          /// 无法确定
    FKPluginAssociationStateAssociated,          /// 已在 FilterKit 内建立管理关系
    FKPluginAssociationStateNotAssociated         /// 未建立管理关系
};

/// 配置状态：来自注入器配置证据；无配置读取通道或证据不足时归 Unknown。
typedef NS_ENUM(NSInteger, FKConfigurationStatus) {
    FKConfigurationStatusUnknown = 0,        /// 无法确定
    FKConfigurationStatusEnabled,            /// 配置中为启用
    FKConfigurationStatusDisabled             /// 配置中为停用
};

/// 运行状态：必须有真实进程加载证据；无证据时归 Unknown，不能由配置状态推断。
typedef NS_ENUM(NSInteger, FKRuntimeStatus) {
    FKRuntimeStatusUnknown = 0,              /// 无运行时证据
    FKRuntimeStatusNotRunning,               /// 目标进程未运行
    FKRuntimeStatusRunning,                   /// 进程运行中，但未确认插件加载
    FKRuntimeStatusLoaded,                   /// 已确认插件加载
    FKRuntimeStatusNotLoaded                  /// 已确认插件未加载
};

/// 备份状态：描述该插件最近一次操作前配置/文件备份的完成情况。
/// 与既有 FKBackupResult.h 的 FKBackupStatus（备份任务状态）区分，避免枚举重定义。
typedef NS_ENUM(NSInteger, FKPluginBackupStatus) {
    FKPluginBackupStatusUnknown = 0,       /// 未检查
    FKPluginBackupStatusNone,               /// 尚未备份
    FKPluginBackupStatusBackedUp,           /// 已完成备份并通过校验
    FKPluginBackupStatusFailed              /// 备份失败或校验未通过
};

/// 事务状态机流转；失败进入回滚，回滚失败转为待人工恢复。
typedef NS_ENUM(NSInteger, FKOperationTransactionState) {
    FKOperationTransactionStateCreated = 0,
    FKOperationTransactionStatePreflight,
    FKOperationTransactionStateGateChecking,
    FKOperationTransactionStateBackup,
    FKOperationTransactionStateAwaitingConfirmation,
    FKOperationTransactionStateApplying,
    FKOperationTransactionStateVerifying,
    FKOperationTransactionStateCompleted,
    FKOperationTransactionStateFailed,
    FKOperationTransactionStateRollback,
    FKOperationTransactionStateRolledBack,
    FKOperationTransactionStateRecoveryRequired
};

/// 准入决策结论。
typedef NS_ENUM(NSInteger, FKOperationDecision) {
    FKOperationDecisionUnknown = 0,          /// 证据不足，无法判定
    FKOperationDecisionAllowed,              /// 必要条件全部满足，允许进入受控流程
    FKOperationDecisionDenied,               /// 必要条件不满足，拒绝执行
    FKOperationDecisionNeedsConfirmation,    /// 存在共享配置/多目标等需人工额外确认
    FKOperationDecisionUnsupported           /// 当前注入器/版本/格式不支持该操作
};

/// 安全模式分级；每种权限只对对应功能开放，0.1.15 固定停留在 PreviewOnly。
typedef NS_ENUM(NSInteger, FKOperationMode) {
    FKOperationModeReadOnly = 0,              /// 只读扫描与查看
    FKOperationModePreviewOnly,               /// 可生成配置/操作预览，不落地修改
    FKOperationModeBackupWrite,               /// 可在 App 沙盒内写入备份
    FKOperationModeAuthorizedManagement       /// 可信通道 + 授权后的真实管理（0.1.15 不进入）
};

/// 插件状态快照：关联 / 配置 / 运行三态独立维护；每次重新扫描重新判定，
/// 不沿用上一次操作结果推断当前状态，配置状态也不推断运行时状态。
@interface FKPluginState : NSObject

@property (nonatomic, copy) NSString *pluginID;
/// 关联的目标 App Bundle ID（可空；全局插件无单一目标）。
@property (nonatomic, copy, nullable) NSString *appBundleID;
@property (nonatomic, assign) FKPluginStatus status;
/// 判定所依据的证据来源描述
@property (nonatomic, copy) NSString *evidence;
/// 最近一次检查时间
@property (nonatomic, copy) NSDate *lastChecked;
/// 识别到的注入器标识
@property (nonatomic, copy) NSString *injector;
/// 当前环境是否支持对该插件执行受控管理
@property (nonatomic, assign) BOOL supported;
/// 不支持管理的原因；supported 为 NO 时填写
@property (nonatomic, copy) NSString *unsupportedReason;

/// 关联状态（管理关系层面）。
@property (nonatomic, assign) FKPluginAssociationState associationStatus;
/// 配置状态（注入器配置证据）。
@property (nonatomic, assign) FKConfigurationStatus configurationStatus;
/// 运行状态（进程加载证据，独立于配置状态）。
@property (nonatomic, assign) FKRuntimeStatus runtimeStatus;
/// 兼容性结论码（复用兼容模型文本码，可空）。
@property (nonatomic, copy, nullable) NSString *compatibilityStatus;
/// 备份状态。
@property (nonatomic, assign) FKPluginBackupStatus backupStatus;
/// 最近一次操作事务 ID。
@property (nonatomic, copy, nullable) NSString *lastOperationID;
/// 最近一次配置验证时间。
@property (nonatomic, copy, nullable) NSDate *lastVerifiedAt;

+ (NSString *)statusText:(FKPluginStatus)status;
+ (NSString *)associationText:(FKPluginAssociationState)status;
+ (NSString *)configurationText:(FKConfigurationStatus)status;
+ (NSString *)runtimeText:(FKRuntimeStatus)status;
+ (NSString *)backupText:(FKPluginBackupStatus)status;
- (NSDictionary *)JSONDictionary;

@end

/// 操作请求：只携带经过扫描验证的插件 ID、目标 App 与操作类型，不允许 App 直接传入文件路径。
@interface FKOperationRequest : NSObject

@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, assign) FKOperationType operation;
@property (nonatomic, copy) NSString *reason;
@property (nonatomic, copy) NSString *backupID;
@property (nonatomic, copy) NSDate *createdAt;
/// 目标 App Bundle ID；全局插件或影响范围明确时填写，多目标时列入 targetAppBundleIDs。
@property (nonatomic, copy, nullable) NSString *appBundleID;
/// 受影响目标 App 列表；共享配置无法明确范围时不应构造可执行请求。
@property (nonatomic, copy, nullable) NSArray<NSString *> *targetAppBundleIDs;
/// 授权上下文（由可信认证机制填充；本期为空，不构成身份认证）。
@property (nonatomic, copy, nullable) NSString *authorization;

+ (instancetype)requestWithPluginID:(NSString *)pluginID operation:(FKOperationType)operation;
+ (instancetype)requestWithPluginID:(NSString *)pluginID
                          appBundleID:(nullable NSString *)appBundleID
                           operation:(FKOperationType)operation;
+ (NSString *)operationText:(FKOperationType)operation;
- (NSDictionary *)JSONDictionary;

@end

/// 操作结果：区分请求被接受、操作已执行、验证成功、失败与恢复成功；请求发送成功不等于启停成功。
@interface FKOperationResult : NSObject

@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, assign) BOOL success;
/// 机器可读错误码；成功为空
@property (nonatomic, copy) NSString *errorCode;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *previousState;
@property (nonatomic, copy) NSString *currentState;
@property (nonatomic, copy) NSString *backupID;
@property (nonatomic, copy) NSDate *completedAt;

/// 操作前配置状态文本。
@property (nonatomic, copy, nullable) NSString *beforeState;
/// 目标（期望）配置状态文本。
@property (nonatomic, copy, nullable) NSString *targetState;
/// 操作后实际配置状态文本（未重新读取时为 Unknown）。
@property (nonatomic, copy, nullable) NSString *afterState;
/// 操作前配置/文件哈希。
@property (nonatomic, copy, nullable) NSString *beforeHash;
/// 操作后配置/文件哈希。
@property (nonatomic, copy, nullable) NSString *afterHash;
/// 配置验证结论码（passed / failed / unknown / none）。
@property (nonatomic, copy, nullable) NSString *verificationResult;
/// 回滚结论码（not_required / rolled_back / rollback_failed / recovery_required / none）。
@property (nonatomic, copy, nullable) NSString *rollbackResult;
/// 失败或拒绝的具体原因。
@property (nonatomic, copy, nullable) NSString *failureReason;
/// 执行操作的 Helper 身份标识（未验证时为空）。
@property (nonatomic, copy, nullable) NSString *helperIdentity;
/// Helper 版本（未验证时为空）。
@property (nonatomic, copy, nullable) NSString *helperVersion;
/// 通信协议版本（未建立通道时为空）。
@property (nonatomic, copy, nullable) NSString *protocolVersion;
/// 本次准入决策。
@property (nonatomic, assign) FKOperationDecision decision;

+ (instancetype)resultWithRequestID:(NSString *)requestID success:(BOOL)success
                          errorCode:(NSString *)errorCode message:(NSString *)message;
- (NSDictionary *)JSONDictionary;

@end

/// 追加式操作审计记录；普通操作不得覆盖历史记录。
@interface FKOperationRecord : NSObject

@property (nonatomic, copy) NSString *operationID;
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, copy) NSString *operation;
@property (nonatomic, copy) NSString *previousState;
@property (nonatomic, copy) NSString *currentState;
/// success / failed / cancelled / unknown
@property (nonatomic, copy) NSString *result;
/// passed / failed / pending / none
@property (nonatomic, copy) NSString *verification;
@property (nonatomic, copy) NSString *backupID;
@property (nonatomic, copy) NSDate *timestamp;
@property (nonatomic, copy) NSString *errorMessage;
/// 操作模式：preview_only（默认）/ real；0.1.15 不产生 real 记录
@property (nonatomic, copy) NSString *mode;
/// 安全检查项快照（字典数组）
@property (nonatomic, copy) NSArray<NSDictionary *> *checks;
/// 阻止 / 存疑原因列表
@property (nonatomic, copy) NSArray<NSString *> *reasons;
/// 记录时 Helper 验证状态（unverified / discovered / verified）
@property (nonatomic, copy) NSString *helperStatus;

/// 目标 App Bundle ID。
@property (nonatomic, copy, nullable) NSString *appBundleID;
/// Helper 身份标识。
@property (nonatomic, copy, nullable) NSString *helperIdentity;
/// Helper 版本。
@property (nonatomic, copy, nullable) NSString *helperVersion;
/// 通信协议版本。
@property (nonatomic, copy, nullable) NSString *protocolVersion;
/// 操作前配置状态。
@property (nonatomic, copy, nullable) NSString *beforeState;
/// 目标配置状态。
@property (nonatomic, copy, nullable) NSString *targetState;
/// 操作后实际配置状态。
@property (nonatomic, copy, nullable) NSString *afterState;
/// 操作前哈希。
@property (nonatomic, copy, nullable) NSString *beforeHash;
/// 操作后哈希。
@property (nonatomic, copy, nullable) NSString *afterHash;
/// 授权上下文快照。
@property (nonatomic, copy, nullable) NSString *authorization;
/// Gate 决策结果码。
@property (nonatomic, copy, nullable) NSString *gateResult;
/// 执行通道结果码。
@property (nonatomic, copy, nullable) NSString *executionResult;
/// 验证结果码。
@property (nonatomic, copy, nullable) NSString *verificationResult;
/// 回滚结果码。
@property (nonatomic, copy, nullable) NSString *rollbackResult;
/// 失败原因。
@property (nonatomic, copy, nullable) NSString *failureReason;

+ (nullable instancetype)recordFromDictionary:(nullable NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
