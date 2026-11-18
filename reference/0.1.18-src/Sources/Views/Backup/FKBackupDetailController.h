#import <UIKit/UIKit.h>

@class FKBackupManager;
@class FKPluginManager;

/// 备份详情页：展示清单条目、摘要与恢复预检查结论（只读，不执行覆盖）。
@interface FKBackupDetailController : UITableViewController

@property (nonatomic, strong) NSDictionary *record;
@property (nonatomic, strong) FKBackupManager *backupManager;
@property (nonatomic, strong) FKPluginManager *pluginManager;

@end
