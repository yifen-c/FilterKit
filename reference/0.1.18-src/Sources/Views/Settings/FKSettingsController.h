#import <UIKit/UIKit.h>

@class FKScanReport;
@class FKPluginManager;
@class FKAppManager;
@class FKAuditManager;
@class FKOperationManager;
@class FKBackupManager;
@class FKHelperTrustReport;
@class FKAssociationManager;
@class FKInjectionPreviewManager;

/// 设置页：只读展示运行环境、扫描统计、安全边界，并提供备份管理与操作历史入口。
@interface FKSettingsController : UITableViewController

@property (nonatomic, strong) FKScanReport *report;
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKAppManager *appManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
@property (nonatomic, strong) FKOperationManager *operationManager;
@property (nonatomic, strong) FKBackupManager *backupManager;
@property (nonatomic, strong) FKHelperTrustReport *trustReport;
@property (nonatomic, strong) FKAssociationManager *associationManager;
@property (nonatomic, strong) FKInjectionPreviewManager *previewManager;

@end
