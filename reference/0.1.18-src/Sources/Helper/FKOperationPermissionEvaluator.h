#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 按操作类型的权限预评估。为既有 FKOperationGate 提供能力维度结论，不另建第二套写门禁。
/// 阶段一：本地只读可评估；IPC 只读需信任链与连接证据；所有真实写操作默认拒绝。
@interface FKOperationPermissionEvaluator : NSObject

/// 评估指定权限是否允许。
/// @param permission 权限键（见 FKHelperCapabilityManager 分类）
/// @param identityVerified Helper 身份是否已验证
/// @param ipcConnected IPC 是否已连接且对端已验证
/// @param protocolCompatible 协议版本是否兼容
/// @param reasons 追加拒绝或存疑说明
+ (BOOL)allowPermission:(NSString *)permission
        identityVerified:(BOOL)identityVerified
             ipcConnected:(BOOL)ipcConnected
      protocolCompatible:(BOOL)protocolCompatible
                 reasons:(NSMutableArray<NSString *> *)reasons;

@end

NS_ASSUME_NONNULL_END
