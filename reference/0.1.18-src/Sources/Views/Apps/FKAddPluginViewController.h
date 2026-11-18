#import <UIKit/UIKit.h>

@class FKPluginManager;
@class FKAppManager;
@class FKAssociationManager;
@class FKCompatibilityManager;
@class FKInjectionPreviewManager;
@class FKAuditManager;
@class FKSecurityAuditManager;

/// 添加插件流程的插件选择页：从已发现插件中选择目标插件，标注已有管理关系与兼容性，
/// 阻止重复关联；0.1.6 仅开放系统发现插件，用户导入 dylib 推迟 0.1.15。
@interface FKAddPluginViewController : UITableViewController <UISearchResultsUpdating>

@property (nonatomic, copy) NSString *appBundleID;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKAppManager *appManager;
@property (nonatomic, strong) FKAssociationManager *associationManager;
@property (nonatomic, strong) FKCompatibilityManager *compatibilityManager;
@property (nonatomic, strong) FKInjectionPreviewManager *previewManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
@property (nonatomic, strong) FKSecurityAuditManager *securityAuditManager;
@property (nonatomic, strong) NSDictionary *trustReport;
@property (nonatomic, copy) NSString *injectorType;

- (instancetype)initWithAppBundleID:(NSString *)appBundleID appName:(NSString *)appName;

@end
