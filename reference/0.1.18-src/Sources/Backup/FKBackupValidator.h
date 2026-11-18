#import <Foundation/Foundation.h>
#import "FKBackupManifest.h"

@class FKPluginModel;

/// 恢复预检查结论。0.1.2 只生成预览，不执行任何系统文件覆盖。
typedef NS_ENUM(NSInteger, FKRestoreStatus) {
    FKRestoreStatusSafeToRestore = 0,   /// 备份完整且当前目标未被改动，理论上可恢复（仍需后续版本授权执行）
    FKRestoreStatusTargetModified,      /// 备份后当前目标文件已被其他程序修改
    FKRestoreStatusBackupCorrupted,     /// 备份缺失或重读摘要不一致
    FKRestoreStatusPackageMismatch,     /// 软件包归属与备份时不一致
    FKRestoreStatusPathMismatch,        /// 文件路径与备份时不一致，或插件已不在扫描结果
    FKRestoreStatusUnknown              /// 证据不足，无法判定
};

/// 备份完整性校验与恢复前冲突检查。纯只读逻辑，不写越狱目录、不覆盖原文件。
@interface FKBackupValidator : NSObject

/// 重读备份目录内文件并重算 SHA-256，与 manifest 条目比对；返回备份是否完整可用。
+ (BOOL)validateBackupAtDirectory:(NSString *)dirPath manifest:(FKBackupManifest *)manifest error:(NSError **)error;

/// 恢复预检查：结合备份清单与当前扫描插件模型，给出结论与原因列表；不执行恢复。
+ (NSDictionary *)restorePreviewForManifest:(FKBackupManifest *)manifest
                               currentModel:(FKPluginModel *)model;

/// 结论状态文案。
+ (NSString *)textForStatus:(FKRestoreStatus)status;
/// 结论状态机器可读标识。
+ (NSString *)codeForStatus:(FKRestoreStatus)status;

@end
