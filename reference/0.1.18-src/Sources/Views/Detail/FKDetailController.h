#import <UIKit/UIKit.h>

@class FKAppManager;
@class FKStateManager;
@class FKOperationManager;
@class FKAuditManager;
@class FKBackupManager;
@class FKHelperTrustReport;
@class FKPluginModel;
@class FKPluginManager;
@class FKAssociationManager;
@class FKInjectionPreviewManager;
@class FKCompatibilityManager;
@class FKSecurityAuditManager;

/// App / 插件详情页：只读展示元数据、关联与状态；管理操作入口跳转预演确认、历史或备份。
@interface FKDetailController : UITableViewController

@property (nonatomic, strong) FKAppManager *appManager;
@property (nonatomic, strong) FKStateManager *stateManager;
@property (nonatomic, strong) FKOperationManager *operationManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
@property (nonatomic, strong) FKBackupManager *backupManager;
@property (nonatomic, strong) FKHelperTrustReport *trustReport;
@property (nonatomic, strong) FKPluginModel *pluginModel;
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKAssociationManager *associationManager;
@property (nonatomic, strong) FKInjectionPreviewManager *previewManager;
@property (nonatomic, strong) FKCompatibilityManager *compatibilityManager;
@property (nonatomic, strong) FKSecurityAuditManager *securityAuditManager;

- (instancetype)initWithItem:(NSDictionary *)item mode:(NSString *)mode allPlugins:(NSArray<NSDictionary *> *)plugins;

@end
