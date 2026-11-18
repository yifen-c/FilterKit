#import <Foundation/Foundation.h>
#import "FKHelperIPCCapabilities.h"

NS_ASSUME_NONNULL_BEGIN

/// 按操作类型细分的权限分类。不使用总开关：本地只读、IPC 只读与写操作分别评估。
/// 阶段一本地只读可评估；IPC 只读与写操作在未通过信任链验收前默认关闭。
@interface FKHelperCapabilityManager : NSObject

/// 本地只读权限键（不依赖 Helper 连接）。
+ (NSSet<NSString *> *)localReadOnlyPermissions;
/// IPC 只读权限键（需可信连接与协议兼容）。
+ (NSSet<NSString *> *)ipcReadOnlyPermissions;
/// 写操作权限键（阶段一全部拒绝）。
+ (NSSet<NSString *> *)writePermissions;

+ (BOOL)isWritePermission:(NSString *)permission;
+ (BOOL)isLocalReadOnlyPermission:(NSString *)permission;
+ (BOOL)isIPCReadOnlyPermission:(NSString *)permission;

/// 阶段一默认能力：仅开放本地只读，IPC 只读与写能力关闭。
+ (FKHelperIPCCapabilities *)defaultCapabilities;

@end

NS_ASSUME_NONNULL_END
