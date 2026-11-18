#import "FKOperationPermissionEvaluator.h"
#import "FKHelperCapabilityManager.h"

@implementation FKOperationPermissionEvaluator

+ (BOOL)allowPermission:(NSString *)permission
        identityVerified:(BOOL)identityVerified
             ipcConnected:(BOOL)ipcConnected
      protocolCompatible:(BOOL)protocolCompatible
                 reasons:(NSMutableArray<NSString *> *)reasons {
    if (permission.length == 0) {
        [reasons addObject:@"未提供待评估的权限键"];
        return NO;
    }

    // 本地只读检查不依赖 Helper 连接，阶段一开放。
    if ([FKHelperCapabilityManager isLocalReadOnlyPermission:permission]) {
        return YES;
    }

    // 写操作：阶段一全部拒绝，不因其他条件满足而放行。
    if ([FKHelperCapabilityManager isWritePermission:permission]) {
        [reasons addObject:@"阶段一未开放真实写操作，启用/禁用/配置修改/删除均已锁定"];
        return NO;
    }

    // IPC 只读：需身份已验证、连接已建立且协议兼容，缺一不可。
    if ([FKHelperCapabilityManager isIPCReadOnlyPermission:permission]) {
        if (!identityVerified) [reasons addObject:@"Helper 身份未验证，IPC 只读不可用"];
        if (!ipcConnected) [reasons addObject:@"IPC 未连接，IPC 只读不可用"];
        if (!protocolCompatible) [reasons addObject:@"协议版本不兼容，IPC 只读不可用"];
        return identityVerified && ipcConnected && protocolCompatible;
    }

    [reasons addObject:[NSString stringWithFormat:@"未识别的权限键：%@", permission]];
    return NO;
}

@end
