#import "FKOperationRollback.h"
#import "FKOperationTransaction.h"

@implementation FKOperationRollback

+ (instancetype)planForTransaction:(FKOperationTransaction *)transaction
                     backupAvailable:(BOOL)backupAvailable
                        backupValid:(BOOL)backupValid
                targetIdentityMatch:(BOOL)identityMatch {
    FKOperationRollback *plan = [self new];
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];

    if (transaction) plan.backupID = transaction.backupID;

    // 尚未产生可感知变更时无需回滚。
    if (!transaction.afterState.length) {
        plan.status = FKRollbackStatusNotRequired;
        [reasons addObject:@"未检测到需要回滚的配置变更"];
        plan.reasons = reasons.copy;
        return plan;
    }
    if (!backupAvailable) {
        plan.status = FKRollbackStatusBackupMissing;
        [reasons addObject:@"缺少操作前配置备份，无法安全回滚"];
    } else if (!backupValid) {
        plan.status = FKRollbackStatusBackupCorrupted;
        [reasons addObject:@"备份校验未通过，不得用于回滚覆盖"];
    } else if (!identityMatch) {
        plan.status = FKRollbackStatusTargetMismatch;
        [reasons addObject:@"当前目标身份与备份时不一致，拒绝按旧备份覆盖"];
    } else {
        plan.status = FKRollbackStatusReady;
        [reasons addObject:@"备份与目标身份前提满足；真实回滚仍须经可信通道与用户授权"];
    }

    plan.reasons = reasons.copy;
    return plan;
}

+ (NSString *)codeForStatus:(FKRollbackStatus)status {
    switch (status) {
        case FKRollbackStatusReady: return @"ready";
        case FKRollbackStatusBackupMissing: return @"backup_missing";
        case FKRollbackStatusBackupCorrupted: return @"backup_corrupted";
        case FKRollbackStatusTargetMismatch: return @"target_mismatch";
        case FKRollbackStatusRecoveryRequired: return @"recovery_required";
        case FKRollbackStatusNotRequired:
        default: return @"not_required";
    }
}

+ (NSString *)textForStatus:(FKRollbackStatus)status {
    switch (status) {
        case FKRollbackStatusReady: return @"可回滚（待授权通道）";
        case FKRollbackStatusBackupMissing: return @"缺少备份";
        case FKRollbackStatusBackupCorrupted: return @"备份损坏";
        case FKRollbackStatusTargetMismatch: return @"目标不一致";
        case FKRollbackStatusRecoveryRequired: return @"需要人工恢复";
        case FKRollbackStatusNotRequired:
        default: return @"无需回滚";
    }
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"status": [FKOperationRollback codeForStatus:self.status],
        @"status_text": [FKOperationRollback textForStatus:self.status],
        @"backup_id": self.backupID ?: @"",
        @"reasons": self.reasons ?: @[]
    };
}

@end
