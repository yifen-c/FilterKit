#import "FKAddPluginViewController.h"
#import "FKPluginManager.h"
#import "FKManageModels.h"
#import "FKAssociationManager.h"
#import "FKCompatibilityManager.h"
#import "FKInjectionPreviewManager.h"
#import "FKAuditManager.h"
#import "FKSecurityAuditManager.h"
#import "FKSecurityEvent.h"
#import "FKInjectionPreviewViewController.h"

@interface FKAddPluginViewController ()
@property (nonatomic, copy) NSArray<FKPluginModel *> *sourcePlugins;
@property (nonatomic, copy) NSArray<FKPluginModel *> *visiblePlugins;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation FKAddPluginViewController

- (instancetype)initWithAppBundleID:(NSString *)appBundleID appName:(NSString *)appName {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _appBundleID = [appBundleID copy];
        _appName = [appName copy];
        _sourcePlugins = @[];
        _visiblePlugins = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"添加插件";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 68;
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索插件名称、包名或 dylib";
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    self.sourcePlugins = self.pluginManager.allPlugins ?: @[];
    [self filterPlugins:self.searchController.searchBar.text ?: @""];
}

- (void)filterPlugins:(NSString *)query {
    NSString *needle = query.lowercaseString;
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(FKPluginModel *model, NSDictionary *bindings) {
        (void)bindings;
        if (!needle.length) return YES;
        NSArray<NSString *> *fields = @[model.name ?: @"", model.pluginID ?: @"", model.packageID ?: @"", model.dylibPath ?: @""];
        for (NSString *text in fields) {
            if ([text.lowercaseString containsString:needle]) return YES;
        }
        return NO;
    }];
    self.visiblePlugins = [self.sourcePlugins filteredArrayUsingPredicate:predicate];
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self filterPlugins:searchController.searchBar.text ?: @""];
}

#pragma mark - 表格

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.visiblePlugins.count ?: 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"FKAddPluginCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.numberOfLines = 3;

    if (!self.visiblePlugins.count) {
        cell.textLabel.text = @"没有匹配的插件";
        cell.detailTextLabel.text = self.sourcePlugins.count ? @"可尝试修改搜索关键词。" : @"当前未发现已安装插件。";
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    FKPluginModel *model = self.visiblePlugins[indexPath.row];
    BOOL already = [self.associationManager hasAssociationForApp:self.appBundleID plugin:model.pluginID];
    BOOL importOnly = ![model.source isEqualToString:@"dpkg"];
    NSString *name = model.name.length ? model.name : model.pluginID;
    NSString *statusText = already ? @"已关联" : (importOnly ? @"用户导入 · 暂不可选（后续版本开放）" : model.integrityStatus ?: @"未关联");
    cell.textLabel.text = name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n来源：%@ · %@", model.dylibPath ?: @"", model.source ?: @"unknown", statusText];
    cell.imageView.image = [UIImage systemImageNamed:@"puzzlepiece.extension"];
    cell.accessoryType = already || importOnly ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = already || importOnly ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.visiblePlugins.count) return;
    FKPluginModel *model = self.visiblePlugins[indexPath.row];

    // 阻止重复创建相同关联。
    if ([self.associationManager hasAssociationForApp:self.appBundleID plugin:model.pluginID]) {
        [self showMessage:@"该插件已关联到此 App，无需重复添加。"];
        return;
    }
    // 0.1.6 只开放系统发现插件；用户导入 dylib 推迟 0.1.15。
    if (![model.source isEqualToString:@"dpkg"]) {
        [self showMessage:@"用户导入插件暂不支持，将在后续版本开放。"];
        return;
    }

    // 记录插件选择审计事件（仅选择，不代表启用）。
    if (self.securityAuditManager) {
        [self.securityAuditManager recordEventType:FKSecurityEventTypePluginSelected
                                            target:model.pluginID
                                            result:@"selected"
                                             reason:@"用户在添加插件流程中选择目标插件"
                                           evidence:@{@"app_bundle_id": self.appBundleID ?: @"", @"plugin_id": model.pluginID ?: @""}];
    }

    FKInjectionPreviewViewController *preview = [[FKInjectionPreviewViewController alloc] initWithAppBundleID:self.appBundleID appName:self.appName pluginID:model.pluginID];
    preview.pluginManager = self.pluginManager;
    preview.appManager = self.appManager;
    preview.associationManager = self.associationManager;
    preview.compatibilityManager = self.compatibilityManager;
    preview.previewManager = self.previewManager;
    preview.auditManager = self.auditManager;
    preview.securityAuditManager = self.securityAuditManager;
    preview.trustReport = self.trustReport;
    preview.injectorType = self.injectorType;
    [self.navigationController pushViewController:preview animated:YES];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"添加插件" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
