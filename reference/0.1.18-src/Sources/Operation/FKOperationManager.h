#import <Foundation/Foundation.h>
#import "FKOperationModels.h"

@class FKPluginManager, FKStateManager, FKAuditManager, FKHelperClient, FKBackupManager;

/// 统一受控操作流程：身份校验 → 兼容性 → 完整性 → 当前状态 → 预演 → 用户确认 → 备份 → 白名单执行 → 重扫验证 → 审计。
/// 预检查不满足时直接拒绝，不尝试强制执行；当前 Helper 未验证，真实启停被安全拒绝。
@interface FKOperationManager : NSObject

- (instancetype)initWithPluginManager:(FKPluginManager *)pluginManager
                          stateManager:(FKStateManager *)stateManager
                          auditManager:(FKAuditManager *)auditManager
                          helperClient:(FKHelperClient *)helperClient;

- (instancetype)initWithPluginManager:(FKPluginManager *)pluginManager
                          stateManager:(FKStateManager *)stateManager
                          auditManager:(FKAuditManager *)auditManager
                          helperClient:(FKHelperClient *)helperClient
                        backupManager:(FKBackupManager *)backupManager;

/// 操作预演：完成全部前置检查并生成影响预览，不执行、不落地备份。
- (NSDictionary *)previewForPluginID:(NSString *)pluginID operation:(FKOperationType)operation;

/// 插件受控操作资格校验。
- (NSDictionary *)validatePlugin:(NSString *)pluginID;

/// 启用插件（当前 Helper 不可用时安全拒绝并记录审计）。
- (void)enablePlugin:(NSString *)pluginID completion:(void (^)(FKOperationResult *result))completion;
/// 停用插件（当前 Helper 不可用时安全拒绝并记录审计）。
- (void)disablePlugin:(NSString *)pluginID completion:(void (^)(FKOperationResult *result))completion;
/// 按操作记录发起受控恢复（预留）。
- (void)restoreOperation:(NSString *)operationID completion:(void (^)(FKOperationResult *result))completion;

@end
