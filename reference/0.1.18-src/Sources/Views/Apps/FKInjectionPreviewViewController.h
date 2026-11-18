#import <UIKit/UIKit.h>

@class FKPluginManager;
@class FKAppManager;
@class FKAssociationManager;
@class FKCompatibilityManager;
@class FKInjectionPreviewManager;
@class FKAuditManager;
@class FKSecurityAuditManager;

/// 注入配置预览页：展示 App / Plugin / Mach-O / Injector / Security 五组检查与冲突警告，
/// 保存的只是 FilterKit 管理关系与预览记录；不写注入器配置、不启停插件、不连接未验证 Helper。
@interface FKInjectionPreviewViewController : UITableViewController

@property (nonatomic, copy) NSString *appBundleID;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKAppManager *appManager;
@property (nonatomic, strong) FKAssociationManager *associationManager;
@property (nonatomic, strong) FKCompatibilityManager *compatibilityManager;
@property (nonatomic, strong) FKInjectionPreviewManager *previewManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
@property (nonatomic, strong) FKSecurityAuditManager *securityAuditManager;
@property (nonatomic, strong) NSDictionary *trustReport;
@property (nonatomic, copy) NSString *injectorType;

- (instancetype)initWithAppBundleID:(NSString *)appBundleID appName:(NSString *)appName pluginID:(NSString *)pluginID;

@end
