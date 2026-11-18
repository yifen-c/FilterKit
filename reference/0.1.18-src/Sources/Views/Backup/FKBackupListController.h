#import <UIKit/UIKit.h>

@class FKBackupManager;
@class FKPluginManager;

/// 备份列表页：展示沙盒内已完成的文件备份。
@interface FKBackupListController : UITableViewController

@property (nonatomic, strong) FKBackupManager *backupManager;
@property (nonatomic, strong) FKPluginManager *pluginManager;

@end
