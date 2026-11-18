#import <UIKit/UIKit.h>

@class FKScanReport;
@class FKAppManager;
@class FKPluginManager;
@class FKAssociationManager;
@class FKInjectionPreviewManager;
@class FKAuditManager;

/// 首页：展示设备与环境状态、注入器、Helper 安全状态、扫描统计与最近活动。
/// 首页不承担插件操作；无证据的运行状态一律不展示为已启用。
@interface FKHomeViewController : UITableViewController

@property (nonatomic, strong) FKScanReport *report;
@property (nonatomic, strong) FKAppManager *appManager;
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKAssociationManager *associationManager;
@property (nonatomic, strong) FKInjectionPreviewManager *previewManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
/// Helper 信任快照字典（TrustEvaluator 产出）。
@property (nonatomic, strong) NSDictionary *trustReport;

/// 扫描完成或数据变化后刷新页面。
- (void)applyReport:(FKScanReport *)report;

@end
