#import <UIKit/UIKit.h>

@class FKScanReport;
@class FKPluginManager;
@class FKAppManager;
@class FKStateManager;
@class FKOperationManager;
@class FKAuditManager;
@class FKBackupManager;
@class FKHelperTrustReport;
@class FKAssociationManager;
@class FKInjectionPreviewManager;
@class FKCompatibilityManager;
@class FKSecurityAuditManager;

/// App / 插件共用列表页：mode 区分展示口径，支持搜索与插件分类筛选。
@interface FKDataListController : UITableViewController <UISearchResultsUpdating>

/// 展示模式：apps / plugins。
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, strong) FKScanReport *report;
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKAppManager *appManager;
@property (nonatomic, strong) FKStateManager *stateManager;
@property (nonatomic, strong) FKOperationManager *operationManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
@property (nonatomic, strong) FKBackupManager *backupManager;
@property (nonatomic, strong) FKHelperTrustReport *trustReport;
@property (nonatomic, strong) FKAssociationManager *associationManager;
@property (nonatomic, strong) FKInjectionPreviewManager *previewManager;
@property (nonatomic, strong) FKCompatibilityManager *compatibilityManager;
@property (nonatomic, strong) FKSecurityAuditManager *securityAuditManager;

- (instancetype)initWithMode:(NSString *)mode;
/// 扫描完成后刷新数据源。
- (void)applyReport:(FKScanReport *)report;

@end
