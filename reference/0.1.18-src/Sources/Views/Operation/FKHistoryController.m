#import "FKHistoryController.h"
#import "FKAuditManager.h"
#import "FKOperationModels.h"

@interface FKHistoryController ()
@property (nonatomic, copy) NSArray<FKOperationRecord *> *filteredRecords;
@property (nonatomic, copy) NSString *filterOperation;
@property (nonatomic, strong) UISegmentedControl *filterSegment;
@property (nonatomic, assign) NSUInteger filterKind;
@end

@implementation FKHistoryController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"操作历史";
    self.filterOperation = @"";
    self.filterKind = 0;
    self.filterSegment = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"启用", @"禁用", @"备份", @"恢复", @"失败", @"回滚"]];
    self.filterSegment.selectedSegmentIndex = 0;
    [self.filterSegment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.filterSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.tableHeaderView = self.filterSegment;
    [self.filterSegment sizeToFit];
    CGRect frame = self.filterSegment.frame;
    frame.size.width = self.tableView.bounds.size.width - 32;
    self.filterSegment.frame = frame;
    [self reloadFiltered];
}

- (void)segmentChanged:(UISegmentedControl *)segment {
    self.filterKind = (NSUInteger)segment.selectedSegmentIndex;
    [self reloadFiltered];
}

- (void)reloadFiltered {
    NSArray<FKOperationRecord *> *records = self.auditManager.records;
    if (self.filterPluginID.length) {
        records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(FKOperationRecord *r, NSDictionary *_) {
            return [r.pluginID isEqualToString:self.filterPluginID];
        }]];
    }
    if (self.filterOperation.length) {
        records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(FKOperationRecord *r, NSDictionary *_) {
            return [r.operation isEqualToString:self.filterOperation];
        }]];
    }

    // 分组筛选：启用 / 禁用 / 备份 / 恢复 / 失败 / 回滚。
    switch (self.filterKind) {
        case 1: records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"operation == %@", @"enable"]]; break;
        case 2: records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"operation == %@", @"disable"]]; break;
        case 3: records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"operation == %@", @"backup"]]; break;
        case 4: records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"operation == %@", @"restore"]]; break;
        case 5: records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"result == %@", @"failed"]]; break;
        case 6: {
            // 回滚码集合限定在本 case 作用域内声明并被 block 捕获，避免 switch 跳转跨越变量生命周期。
            NSSet<NSString *> *rollbackCodes = [NSSet setWithArray:@[@"rolled_back", @"rollback_failed", @"recovery_required"]];
            records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(FKOperationRecord *r, NSDictionary *_) {
                return r.rollbackResult.length && [rollbackCodes containsObject:r.rollbackResult];
            }]];
            break;
        }
        default: break;
    }
    self.filteredRecords = records;
    [self.tableView reloadData];
}

/// Helper 状态文案映射；未知原值兜底。
static NSString *FKHelperStatusText(NSString *status) {
    if ([status isEqualToString:@"verified"]) return @"已验证";
    if ([status isEqualToString:@"discovered"]) return @"已发现";
    if ([status isEqualToString:@"unverified"]) return @"未验证";
    return status.length ? status : @"未验证";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section; return self.filteredRecords.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"FKHistory";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    FKOperationRecord *record = self.filteredRecords[indexPath.row];
    NSDate *timestamp = record.timestamp ?: [NSDate date];
    NSString *time = [NSDateFormatter localizedStringFromDate:timestamp dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@", record.operation ?: @"", record.pluginID ?: @""];
    NSString *appText = record.appBundleID.length ? record.appBundleID : @"全局 / 未指定";
    NSString *stateText = [NSString stringWithFormat:@"%@ → %@",
                           record.beforeState.length ? record.beforeState : (record.previousState ?: @"未知"),
                           record.afterState.length ? record.afterState : (record.currentState ?: @"未确认")];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"目标：%@\n结果：%@ · 验证：%@ · 回滚：%@ · Helper：%@\n状态：%@ · 备份：%@\n%@",
                                  appText, record.result ?: @"", record.verificationResult ?: record.verification ?: @"none",
                                  record.rollbackResult ?: @"not_required", FKHelperStatusText(record.helperStatus),
                                  stateText, record.backupID ?: @"无", time ?: @""];
    cell.detailTextLabel.numberOfLines = 3;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FKOperationRecord *record = self.filteredRecords[indexPath.row];
    NSData *data = [NSJSONSerialization dataWithJSONObject:record.JSONDictionary options:NSJSONWritingPrettyPrinted error:nil];
    NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : record.JSONDictionary.description;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"操作详情" message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
