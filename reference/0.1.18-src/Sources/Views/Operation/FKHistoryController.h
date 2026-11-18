#import <UIKit/UIKit.h>

@class FKAuditManager;

/// 操作历史页：追加式审计记录，支持按插件或操作类型筛选与查看详情。
@interface FKHistoryController : UITableViewController

@property (nonatomic, strong) FKAuditManager *auditManager;
/// 仅展示指定插件的记录；为空展示全部。
@property (nonatomic, copy) NSString *filterPluginID;

@end
