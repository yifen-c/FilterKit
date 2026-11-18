#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper Foundation 详情页：按身份 / 信任状态 / 通信 / 能力四个区域只读展示。
/// 无真实 Helper 时不显示“连接成功”；Unknown 不使用通过样式；Unavailable 与 Failed 分开；
/// 模拟数据标注 Mock。本页面只展示证据，不发起任何写操作。
@interface FKHelperDetailsViewController : UITableViewController

/// Helper 信任快照字典（TrustEvaluator 产出的报告 JSON 段）；传入 nil 按无可信证据展示。
@property (nonatomic, copy, nullable) NSDictionary *helperSnapshot;

@end

NS_ASSUME_NONNULL_END
