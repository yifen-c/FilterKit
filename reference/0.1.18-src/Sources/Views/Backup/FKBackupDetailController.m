#import "FKBackupDetailController.h"
#import "FKPluginManager.h"
#import "FKBackupManager.h"
#import "FKBackupManifest.h"
#import "FKBackupValidator.h"
#import "FKOperationModels.h"

@interface FKBackupDetailController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@end

@implementation FKBackupDetailController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"备份详情";
    [self buildRows];
}

- (void)buildRows {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    NSDictionary *r = self.record ?: @{};
    NSString *pluginID = r[@"plugin_id"] ?: @"";
    FKPluginModel *model = [self.pluginManager pluginForID:pluginID];
    NSString *name = model.name.length ? model.name : pluginID;

    [rows addObject:@{@"title":@"备份 ID", @"value": r[@"backup_id"] ?: @""}];
    [rows addObject:@{@"title":@"插件", @"value": name}];
    [rows addObject:@{@"title":@"软件包", @"value": r[@"package_id"] ?: @"未知"}];
    [rows addObject:@{@"title":@"操作", @"value": r[@"operation"] ?: @"backup"}];
    [rows addObject:@{@"title":@"备份时间", @"value": r[@"created_at"] ?: @"未知"}];
    [rows addObject:@{@"title":@"文件数", @"value": [r[@"file_count"] description] ?: @"0"}];

    // 恢复预检查：结合备份清单与当前扫描模型给出结论，不执行覆盖。
    FKBackupManifest *manifest = [FKBackupManifest manifestFromDictionary:r];
    NSDictionary *preview = [FKBackupValidator restorePreviewForManifest:manifest currentModel:model];
    [rows addObject:@{@"title":@"恢复预览", @"value": preview[@"text"] ?: @"未知"}];
    NSArray *reasons = [preview[@"reasons"] isKindOfClass:NSArray.class] ? preview[@"reasons"] : @[];
    if (reasons.count) [rows addObject:@{@"title":@"预览原因", @"value":[reasons componentsJoinedByString:@"\n"]}];

    // 备份文件条目：原始路径、类型、大小、权限与双摘要。
    NSArray *files = [r[@"files"] isKindOfClass:NSArray.class] ? r[@"files"] : @[];
    for (NSDictionary *f in files) {
        double kb = [f[@"size"] unsignedLongLongValue] / 1024.0;
        NSString *detail = [NSString stringWithFormat:@"类型：%@ · 大小：%.1f KB · 权限：%@\nMD5：%@\nSHA-256：%@",
                            f[@"file_type"] ?: @"unknown", kb, f[@"mode"] ?: @"", f[@"md5"] ?: @"", f[@"sha256"] ?: @""];
        [rows addObject:@{@"title": f[@"original_path"] ?: @"", @"value": detail}];
    }
    [rows addObject:@{@"title":@"说明", @"value":@"备份文件仅存于 App 沙盒；本页为只读预览，0.1.15 不自动恢复或覆盖任何越狱文件。"}];
    self.rows = rows.copy;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section; return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"FKBackupDetail";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    NSDictionary *row = self.rows[indexPath.row];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = [row[@"value"] description];
    cell.detailTextLabel.numberOfLines = 0;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end
