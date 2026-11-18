#import <Foundation/Foundation.h>

@class FKOperationTransaction;

NS_ASSUME_NONNULL_BEGIN

/// 回滚前提评估结论。回滚只做前提校验与计划记录，不覆盖任何越狱系统文件。
typedef NS_ENUM(NSInteger, FKRollbackStatus) {
    FKRollbackStatusNotRequired = 0,   /// 操作未产生变更，无需回滚
    FKRollbackStatusReady,              /// 前提满足，理论可进入受控回滚（仍需后续版本授权通道）
    FKRollbackStatusBackupMissing,      /// 缺少操作前备份
    FKRollbackStatusBackupCorrupted,     /// 备份损坏或校验未通过
    FKRollbackStatusTargetMismatch,      /// 目标身份与备份时不一致
    FKRollbackStatusRecoveryRequired     /// 前提不足，需人工恢复
};

/// 回滚计划：在触发真实回滚前校验备份完整性、目标身份与当前配置一致性；
/// 本类不执行文件覆盖，只输出评估结论与原因列表。
@interface FKOperationRollback : NSObject

/// 评估结论。
@property (nonatomic, assign) FKRollbackStatus status;
/// 原因 / 阻断项列表。
@property (nonatomic, copy) NSArray<NSString *> *reasons;
/// 关联的操作前备份 ID。
@property (nonatomic, copy, nullable) NSString *backupID;

/// 依据事务与备份前提生成回滚计划；不接触系统文件。
+ (instancetype)planForTransaction:(nullable FKOperationTransaction *)transaction
                     backupAvailable:(BOOL)backupAvailable
                        backupValid:(BOOL)backupValid
                targetIdentityMatch:(BOOL)identityMatch;

+ (NSString *)codeForStatus:(FKRollbackStatus)status;
+ (NSString *)textForStatus:(FKRollbackStatus)status;
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
