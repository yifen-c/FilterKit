#import "FKDataListController.h"
#import "FKScanner.h"
#import "FKPluginManager.h"
#import "FKAppManager.h"
#import "FKStateManager.h"
#import "FKOperationManager.h"
#import "FKAuditManager.h"
#import "FKBackupManager.h"
#import "FKHelperTrust.h"
#import "FKOperationModels.h"
#import "FKManageModels.h"
#import "FKAssociationManager.h"
#import "FKDetailController.h"

@interface FKDataListController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *sourceItems;
@property (nonatomic, copy) NSArray<NSDictionary *> *visibleItems;
@property (nonatomic, copy) NSArray<FKPluginModel *> *visiblePlugins;
@property (nonatomic, assign) FKPluginFilter activeFilter;
@property (nonatomic, strong) UISegmentedControl *filterSegment;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation FKDataListController

- (instancetype)initWithMode:(NSString *)mode {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _mode = [mode copy];
        _sourceItems = @[];
        _visibleItems = @[];
        _visiblePlugins = @[];
        _activeFilter = FKPluginFilterAll;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 68;
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = [self.mode isEqualToString:@"apps"] ? @"搜索 App 名称或 Bundle ID" : @"搜索插件、包名或 dylib";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = YES;
    self.definesPresentationContext = YES;
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;

    if ([self.mode isEqualToString:@"plugins"]) {
        self.filterSegment = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"已关联", @"全局", @"未匹配", @"异常", @"警告"]];
        self.filterSegment.selectedSegmentIndex = 0;
        [self.filterSegment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        self.filterSegment.translatesAutoresizingMaskIntoConstraints = NO;
        self.tableView.tableHeaderView = self.filterSegment;
        [self.filterSegment sizeToFit];
        CGRect frame = self.filterSegment.frame;
        frame.size.width = self.tableView.bounds.size.width - 32;
        self.filterSegment.frame = frame;
    }
}

- (void)segmentChanged:(UISegmentedControl *)segment {
    self.activeFilter = (FKPluginFilter)segment.selectedSegmentIndex;
    [self filterItems:self.searchController.searchBar.text ?: @""];
}

- (void)applyReport:(FKScanReport *)report {
    self.report = report;
    self.sourceItems = [self.mode isEqualToString:@"apps"] ? (report.apps ?: @[]) : (report.plugins ?: @[]);
    [self filterItems:self.searchController.searchBar.text ?: @""];
}

- (void)filterItems:(NSString *)query {
    if ([self.mode isEqualToString:@"apps"]) {
        if (!query.length) {
            self.visibleItems = self.sourceItems;
        } else {
            NSString *needle = query.lowercaseString;
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
                (void)bindings;
                NSArray *values = @[item[@"name"] ?: @"", item[@"bundle_id"] ?: @"", item[@"executable"] ?: @"", item[@"version"] ?: @""];
                for (id value in values) {
                    if ([value isKindOfClass:NSString.class]) {
                        NSString *text = (NSString *)value;
                        if ([text.lowercaseString containsString:needle]) return YES;
                    }
                }
                // 搜索关联插件名称 / dylib 文件名也能定位到对应 App。
                NSString *bundleID = item[@"bundle_id"] ?: @"";
                for (FKPluginModel *plugin in [self.appManager pluginsForApp:bundleID]) {
                    NSArray<NSString *> *fields = @[plugin.name ?: @"", plugin.dylibPath ?: @"", plugin.pluginID ?: @""];
                    for (NSString *text in fields) {
                        if ([text.lowercaseString containsString:needle]) return YES;
                    }
                }
                return NO;
            }];
            self.visibleItems = [self.sourceItems filteredArrayUsingPredicate:predicate];
        }
        [self.tableView reloadData];
        return;
    }

    // 插件：先按分段类别筛选，再在结果内搜索；搜索不重新执行扫描。
    NSArray<FKPluginModel *> *base = self.pluginManager ? [self.pluginManager pluginsWithFilter:self.activeFilter] : @[];
    NSString *needle = query.lowercaseString;
    NSArray<FKPluginModel *> *result = base;
    if (needle.length) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(FKPluginModel *m, NSDictionary *bindings) {
            (void)bindings;
            NSArray<NSString *> *fields = @[m.name ?: @"", m.pluginID ?: @"", m.packageID ?: @"", m.dylibPath ?: @"", m.version ?: @""];
            for (NSString *text in fields) {
                if ([text.lowercaseString containsString:needle]) return YES;
            }
            return NO;
        }];
        result = [base filteredArrayUsingPredicate:predicate];
    }
    self.visiblePlugins = result;
    self.visibleItems = [result valueForKey:@"raw"];
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self filterItems:searchController.searchBar.text ?: @""];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.visibleItems.count ?: 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"FKDataCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.numberOfLines = 3;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.imageView.image = nil;
    if (!self.visibleItems.count) {
        cell.textLabel.text = self.report ? @"没有匹配的数据" : @"正在扫描设备…";
        cell.detailTextLabel.text = self.report ? @"可尝试修改搜索关键词。" : @"扫描完成后将在此显示结果。";
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    NSDictionary *item = self.visibleItems[indexPath.row];
    if ([self.mode isEqualToString:@"apps"]) {
        NSString *bundleID = item[@"bundle_id"] ?: @"";
        NSArray<FKPluginModel *> *linked = self.appManager ? [self.appManager pluginsForApp:bundleID] : @[];
        NSUInteger relationCount = self.associationManager ? [self.associationManager associationsForApp:bundleID].count : 0;
        // 配置状态统计来自注入器配置证据（状态管理器派生），不用管理关系数量代替。
        NSUInteger enabledCount = 0, disabledCount = 0, unknownCount = 0;
        for (FKPluginModel *plugin in linked) {
            FKPluginState *state = self.stateManager ? [self.stateManager stateForPluginID:plugin.pluginID] : nil;
            if (state.configurationStatus == FKConfigurationStatusEnabled) enabledCount++;
            else if (state.configurationStatus == FKConfigurationStatusDisabled) disabledCount++;
            else unknownCount++;
        }
        cell.textLabel.text = item[@"name"] ?: bundleID;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n版本：%@ · 管理关系：%lu · 插件：%lu（已启用 %lu · 已禁用 %lu · 未确认 %lu）",
                                      bundleID, [item[@"version"] length] ? item[@"version"] : @"未知",
                                      (unsigned long)relationCount, (unsigned long)linked.count,
                                      (unsigned long)enabledCount, (unsigned long)disabledCount, (unsigned long)unknownCount];
        NSString *iconPath = item[@"icon_path"];
        UIImage *icon = [iconPath isKindOfClass:NSString.class] && iconPath.length ? [UIImage imageWithContentsOfFile:iconPath] : nil;
        if (!icon) {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(42, 42), NO, 0);
            CGRect rect = CGRectMake(0, 0, 42, 42);
            [[UIColor secondarySystemBackgroundColor] setFill];
            [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:9] fill];
            NSString *appName = [(item[@"name"] ?: @"?") description];
            NSString *initial = appName.length ? [appName substringToIndex:1] : @"?";
            NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
            paragraph.alignment = NSTextAlignmentCenter;
            [initial drawInRect:CGRectMake(0, 5, 42, 32) withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:22], NSForegroundColorAttributeName:UIColor.secondaryLabelColor, NSParagraphStyleAttributeName:paragraph}];
            icon = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        cell.imageView.image = icon;
        cell.imageView.layer.cornerRadius = 9;
        cell.imageView.clipsToBounds = YES;
    } else {
        FKPluginModel *model = indexPath.row < (NSInteger)self.visiblePlugins.count ? self.visiblePlugins[indexPath.row] : nil;
        NSString *name = model.name.length ? model.name : (model.pluginID.length ? model.pluginID : @"未命名插件");
        NSString *version = model.version.length ? model.version : @"未知";
        NSString *package = model.packageID.length ? model.packageID : @"未知来源";
        NSString *matchText = model.isGlobal ? @"全局注入" : (model.associatedBundleIDs.count ? [model.associatedBundleIDs componentsJoinedByString:@", "] : @"未映射到具体 App");
        cell.textLabel.text = name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n包：%@ · 版本：%@ · %@\n关联 %lu · %@",
                                      model.dylibPath ?: @"", package, version, model.integrityStatus ?: @"未知",
                                      (unsigned long)model.associatedBundleIDs.count, matchText];
        cell.imageView.image = [UIImage systemImageNamed:@"puzzlepiece.extension"];
        cell.imageView.tintColor = UIColor.secondaryLabelColor;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.visibleItems.count) return;
    NSDictionary *item = self.visibleItems[indexPath.row];
    FKDetailController *detail = [[FKDetailController alloc] initWithItem:item mode:self.mode allPlugins:self.report.plugins ?: @[]];
    detail.appManager = self.appManager;
    detail.pluginManager = self.pluginManager;
    detail.stateManager = self.stateManager;
    detail.operationManager = self.operationManager;
    detail.auditManager = self.auditManager;
    detail.backupManager = self.backupManager;
    detail.trustReport = self.trustReport;
    detail.associationManager = self.associationManager;
    detail.previewManager = self.previewManager;
    detail.compatibilityManager = self.compatibilityManager;
    detail.securityAuditManager = self.securityAuditManager;
    [self.navigationController pushViewController:detail animated:YES];
}

@end
