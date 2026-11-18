#import <Foundation/Foundation.h>

/// 安全事件类型。覆盖环境探测、注入器识别、Helper 发现/身份/签名/权限/IPC、准入判断与拒绝。
typedef NS_ENUM(NSInteger, FKSecurityEventType) {
    FKSecurityEventTypeEnvironment = 0,   /// 环境探测
    FKSecurityEventTypeInjector,         /// 注入器识别
    FKSecurityEventTypeHelperDiscover,   /// Helper 发现
    FKSecurityEventTypeHelperIdentity,  /// Helper 身份验证
    FKSecurityEventTypeHelperSignature,  /// Helper 签名验证
    FKSecurityEventTypeHelperPermission, /// Helper 权限验证
    FKSecurityEventTypeIPC,              /// IPC 协议验证
    FKSecurityEventTypeGateEvaluation,   /// 准入判断
    FKSecurityEventTypeGateRejection,   /// 准入拒绝
    FKSecurityEventTypeScanStarted,     /// 扫描开始
    FKSecurityEventTypeScanCompleted,   /// 扫描完成
    FKSecurityEventTypeBackup,          /// 文件备份结果
    FKSecurityEventTypeTestExecution,   /// 自动化测试执行
    FKSecurityEventTypeReportExport,     /// 报告导出
    FKSecurityEventTypeAppOpened,       /// 打开 App 详情
    FKSecurityEventTypeAppSearched,      /// 搜索 App
    FKSecurityEventTypePluginSelected,  /// 选择目标插件
    FKSecurityEventTypeAssociationPreviewed, /// 关联关系预演
    FKSecurityEventTypeAssociationCreated,    /// 建立管理关系
    FKSecurityEventTypeAssociationRemoved,   /// 移除管理关系
    FKSecurityEventTypeInjectionPreviewCreated, /// 生成注入配置预览
    FKSecurityEventTypeCompatibilityChecked,   /// 兼容性检查
    FKSecurityEventTypeOperationDenied,       /// 安全门禁拒绝操作
    FKSecurityEventTypeTransactionCreated,    /// 事务创建
    FKSecurityEventTypeTransactionCompleted,  /// 事务完成
    FKSecurityEventTypeTransactionFailed,     /// 事务失败
    FKSecurityEventTypeRollbackRequired,      /// 触发回滚判断
    FKSecurityEventTypeRollbackCompleted,      /// 回滚完成
    FKSecurityEventTypeVerificationPassed,      /// 配置验证通过
    FKSecurityEventTypeVerificationFailed,     /// 配置验证未通过
    FKSecurityEventTypeConfigurationBackupCreated, /// 操作前配置快照备份
    FKSecurityEventTypeManifestValidation,    /// Helper 发布清单校验
    FKSecurityEventTypeIntegrityCheck,       /// 文件完整性摘要校验
    FKSecurityEventTypeProtocolValidation,    /// v1 协议版本与握手校验
    FKSecurityEventTypeCapabilityEvaluation,  /// 只读/写能力评估
    FKSecurityEventTypeOperationRejected      /// 受控操作被门禁拒绝
};

/// 单条安全证据事件。追加写入后普通流程不得修改历史事件。
@interface FKSecurityEvent : NSObject

/// 事件唯一标识
@property (nonatomic, copy) NSString *eventID;
/// 事件类型码
@property (nonatomic, copy) NSString *eventType;
/// 事件时间
@property (nonatomic, copy) NSDate *timestamp;
/// 目标对象（如 RootHelper、注入器标识、插件 ID）
@property (nonatomic, copy) NSString *target;
/// 结论（verified / unverified / rejected / unknown / passed）
@property (nonatomic, copy) NSString *result;
/// 原因或说明
@property (nonatomic, copy) NSString *reason;
/// 证据来源与明细字典
@property (nonatomic, copy) NSDictionary *evidence;

+ (NSString *)typeCodeForType:(FKSecurityEventType)type;
+ (instancetype)eventWithType:(FKSecurityEventType)type
                        target:(NSString *)target
                        result:(NSString *)result
                        reason:(NSString *)reason
                      evidence:(NSDictionary *)evidence;
+ (instancetype)eventFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

@end
