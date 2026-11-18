#import "FKBackupListController.h"
#import "FKPluginManager.h"
#import "FKBackupManager.h"
#import "FKOperationModels.h"
#import "FKBackupDetailController.h"
#import <math.h>

/// 按字节数输出可读容量。
static NSString *FKFormatBytes(unsigned long long bytes) {
    if (bytes < 1024) return [NSString stringWithFormat:@"%llu B", bytes];
    double kb = bytes / 1024.0;
    if (kb < 1024) return [NSString stringWithFormat:@"%.1f KB", kb];
    return [NSString stringWithFormat:@"%.1f MB", kb / 1024.0];
}

@interface FKBackupListController ()
/// 行数据：@{@"kind": @"active"|@"record", @"result": FKBackupResult, @"record": NSDictionary}
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@end

@implementation FKBackupListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"备份管理";
    [self reloadRows];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleBackupDidFinish:)
                                               name:FKBackupDidFinishNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleBackupDidProgress:)
                                               name:FKBackupProgressNotification
                                             object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

/// 重新合并进行中任务与历史备份记录并刷新列表。
- (void)reloadRows {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    for (FKBackupResult *result in self.backupManager.activeBackupResults) {
        [rows addObject:@{@"kind": @"active", @"result": result}];
    }
    for (NSDictionary *record in self.backupManager.allBackups) {
        [rows addObject:@{@"kind": @"record", @"record": record}];
    }
    self.rows = rows.copy;
    [self.tableView reloadData];
}

- (void)handleBackupDidFinish:(NSNotification *)notification {
    // 备份完成 / 失败 / 取消均刷新，失败记录也保留展示。
    [self reloadRows];
}

- (void)handleBackupDidProgress:(NSNotification *)notification {
    // 进度更新后刷新对应行；列表为短表，整体重载即可。
    [self reloadRows];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section; return self.rows.count ?: 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"FKBackupList";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    cell.detailTextLabel.numberOfLines = 2;

    if (!self.rows.count) {
        cell.textLabel.text = @"暂无备份";
        cell.detailTextLabel.text = @"在插件详情页执行「备份插件」后，记录将显示在此处。";
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    NSDictionary *row = self.rows[indexPath.row];
    NSString *kind = row[@"kind"];
    if ([kind isEqualToString:@"active"]) {
        [self configureActiveCell:cell result:row[@"result"]];
    } else {
        [self configureRecordCell:cell record:row[@"record"]];
    }
    return cell;
}

/// 进行中行：展示状态、进度百分比与当前处理文件。
- (void)configureActiveCell:(UITableViewCell *)cell result:(FKBackupResult *)result {
    NSString *pluginID = result.pluginID ?: @"";
    FKPluginModel *model = [self.pluginManager pluginForID:pluginID];
    cell.textLabel.text = model.name.length ? model.name : pluginID;

    NSUInteger percent = (NSUInteger)round(result.progress * 100.0);
    NSString *statusText = [FKBackupResult textForStatus:result.status];
    NSString *currentFile = result.currentFile.length ? result.currentFile : @"准备中";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %lu%%\n当前文件：%@",
                                 statusText, (unsigned long)percent, currentFile];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
}

/// 历史记录行：展示包归属、文件数、总大小与 SHA-256 校验状态。
- (void)configureRecordCell:(UITableViewCell *)cell record:(NSDictionary *)record {
    NSString *pluginID = record[@"plugin_id"] ?: @"";
    FKPluginModel *model = [self.pluginManager pluginForID:pluginID];
    cell.textLabel.text = model.name.length ? model.name : pluginID;

    NSArray<NSDictionary *> *files = [record[@"files"] isKindOfClass:NSArray.class] ? record[@"files"] : @[];
    unsigned long long totalSize = 0;
    BOOL shaRecorded = YES;
    for (NSDictionary *file in files) {
        totalSize += [file[@"size"] unsignedLongLongValue];
        if (![file[@"sha256"] length]) shaRecorded = NO;
    }
    NSUInteger fileCount = [record[@"file_count"] unsignedIntegerValue] ?: files.count;
    NSString *sizeText = files.count ? FKFormatBytes(totalSize) : @"—";
    NSString *shaText = files.count ? (shaRecorded ? @"SHA-256 验证通过" : @"摘要不完整") : @"—";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"包：%@ · %lu 个文件 · %@\n%@ · %@",
                                 record[@"package_id"] ?: @"未知", (unsigned long)fileCount,
                                 sizeText, shaText, record[@"created_at"] ?: @""];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.rows.count) return;
    NSDictionary *row = self.rows[indexPath.row];
    if (![row[@"kind"] isEqualToString:@"record"]) return; // 进行中任务无可展示明细。
    FKBackupDetailController *detail = [[FKBackupDetailController alloc] init];
    detail.record = row[@"record"];
    detail.backupManager = self.backupManager;
    detail.pluginManager = self.pluginManager;
    [self.navigationController pushViewController:detail animated:YES];
}

@end
