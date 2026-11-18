#import "FKHelperCapabilityManager.h"

@implementation FKHelperCapabilityManager

+ (NSSet<NSString *> *)localReadOnlyPermissions {
    return [NSSet setWithArray:@[@"local.helper.inspect", @"local.plugin.inspect"]];
}

+ (NSSet<NSString *> *)ipcReadOnlyPermissions {
    return [NSSet setWithArray:@[@"ipc.plugin.list", @"ipc.config.read"]];
}

+ (NSSet<NSString *> *)writePermissions {
    return [NSSet setWithArray:@[@"plugin.enable", @"plugin.disable", @"config.write", @"plugin.delete"]];
}

+ (BOOL)isWritePermission:(NSString *)permission {
    return permission.length > 0 && [[self writePermissions] containsObject:permission];
}

+ (BOOL)isLocalReadOnlyPermission:(NSString *)permission {
    return permission.length > 0 && [[self localReadOnlyPermissions] containsObject:permission];
}

+ (BOOL)isIPCReadOnlyPermission:(NSString *)permission {
    return permission.length > 0 && [[self ipcReadOnlyPermissions] containsObject:permission];
}

+ (FKHelperIPCCapabilities *)defaultCapabilities {
    // 阶段一：仅本地只读进入能力清单；IPC 只读与写能力保持关闭。
    NSArray<NSString *> *readOnly = [[self localReadOnlyPermissions] allObjects];
    return [FKHelperIPCCapabilities capabilitiesWithReadOnly:readOnly write:@[]];
}

@end
