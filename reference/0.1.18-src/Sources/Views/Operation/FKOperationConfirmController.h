#import <UIKit/UIKit.h>
#import "FKOperationModels.h"

@class FKOperationManager;
@class FKAuditManager;
@class FKBackupManager;
@class FKHelperTrustReport;
@class FKPluginModel;

/// 操作预演确认页：展示前置检查与影响预览，用户确认后才进入受控流程；当前版本停留只读预演。
@interface FKOperationConfirmController : UITableViewController

- (instancetype)initWithPluginID:(NSString *)pluginID
                        operation:(FKOperationType)operation
                  operationManager:(FKOperationManager *)operationManager
                     auditManager:(FKAuditManager *)auditManager
                    backupManager:(FKBackupManager *)backupManager
                      trustReport:(FKHelperTrustReport *)trustReport
                            model:(FKPluginModel *)model
                         injector:(NSString *)injector;

@end
