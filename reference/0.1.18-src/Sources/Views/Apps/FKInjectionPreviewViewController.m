#import "FKInjectionPreviewViewController.h"
#import "FKPluginManager.h"
#import "FKAppManager.h"
#import "FKManageModels.h"
#import "FKAppPluginAssociation.h"
#import "FKAssociationManager.h"
#import "FKCompatibilityManager.h"
#import "FKInjectionPreviewManager.h"
#import "FKPluginCompatibility.h"
#import "FKInjectionPreview.h"
#import "FKAuditManager.h"
#import "FKSecurityAuditManager.h"
#import "FKSecurityEvent.h"

@interface FKInjectionPreviewViewController ()
@property (nonatomic, strong) FKPluginModel *pluginModel;
@property (nonatomic, strong) FKAppModel *appModel;
@property (nonatomic, strong) FKPluginCompatibility *compatibility;
@property (nonatomic, strong) FKInjectionPreview *preview;
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@property (nonatomic, assign) BOOL relationSaved;
@end

@implementation FKInjectionPreviewViewController

- (instancetype)initWithAppBundleID:(NSString *)appBundleID appName:(NSString *)appName pluginID:(NSString *)pluginID {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _appBundleID = [appBundleID copy];
        _appName = [appName copy];
        _pluginID = [pluginID copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"配置预览";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
    [self resolveModels];
    [self buildAndRecordPreview];
    [self rebuildRows];
}

- (void)resolveModels {
    self.pluginModel = [self.pluginManager pluginForID:self.pluginID];
    self.appModel = [self.appManager appForBundleID:self.appBundleID];
}

- (void)buildAndRecordPreview {
    BOOL already = [self.associationManager hasAssociationForApp:self.appBundleID plugin:self.pluginID];
    self.compatibility = [self.compatibilityManager evaluatePlugin:self.pluginModel
                                                            forApp:self.appModel
                                                       injectorType:self.injectorType
                                                  alreadyAssociated:already];
    self.preview = [self.previewManager buildPreviewForApp:self.appModel
                                                    plugin:self.pluginModel
                                               injectorType:self.injectorType
                                            compatibility:self.compatibility
                                                trustReport:self.trustReport];
    // 保存本次预览快照（仅预览记录，不代表配置已写入）。
    [self.previewManager savePreview:self.preview];

    if (self.securityAuditManager) {
        [self.securityAuditManager recordEventType:FKSecurityEventTypeInjectionPreviewCreated
                                            target:self.preview.previewID
                                            result:self.preview.result
                                             reason:@"生成注入配置预览"
                                           evidence:@{@"app_bundle_id": self.appBundleID ?: @"", @"plugin_id": self.pluginID ?: @"", @"preview_id": self.preview.previewID ?: @""}];
        [self.securityAuditManager recordEventType:FKSecurityEventTypeCompatibilityChecked
                                            target:self.pluginID
                                            result:[FKPluginCompatibility statusCode:self.compatibility.status]
                                             reason:[FKPluginCompatibility statusText:self.compatibility.status]
                                           evidence:self.compatibility.JSONDictionary];
    }
}

#pragma mark - 行组装

- (void)rebuildRows {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    FKPluginModel *plugin = self.pluginModel;

    // 目标信息。
    [rows addObject:@{@"section": @"目标", @"title": @"目标 App", @"value": self.appName.length ? self.appName : self.appBundleID}];
    [rows addObject:@{@"section": @"目标", @"title": @"Bundle ID", @"value": self.appBundleID}];
    [rows addObject:@{@"section": @"目标", @"title": @"目标插件", @"value": plugin.name.length ? plugin.name : self.pluginID}];

    // 目标配置规则（静态 Filter 证据；仅预览，不代表已写入注入器配置）。
    NSArray<NSString *> *bundles = plugin.filter.bundles ?: @[];
    NSArray<NSString *> *executables = plugin.filter.executables ?: @[];
    NSArray<NSString *> *classes = plugin.filter.classes ?: @[];
    [rows addObject:@{@"section": @"目标配置", @"title": @"Bundles", @"value": bundles.count ? [bundles componentsJoinedByString:@", "] : @"未声明"}];
    [rows addObject:@{@"section": @"目标配置", @"title": @"Executables", @"value": executables.count ? [executables componentsJoinedByString:@", "] : @"未声明"}];
    [rows addObject:@{@"section": @"目标配置", @"title": @"Classes", @"value": classes.count ? [classes componentsJoinedByString:@", "] : @"未声明"}];

    // Helper 分层验证概览：任一未通过即不可视为可信通道。
    NSDictionary *report = self.trustReport ?: @{};
    BOOL identity = [report[@"identity_verified"] boolValue];
    BOOL signature = [report[@"signature_verified"] boolValue];
    BOOL permission = [report[@"permission_verified"] boolValue];
    BOOL ipc = [report[@"ipc_verified"] boolValue];
    [rows addObject:@{@"section": @"Helper 验证", @"title": @"身份 / 签名 / 权限 / IPC",
                      @"value": [NSString stringWithFormat:@"%@ / %@ / %@ / %@",
                                 identity ? @"已验证" : @"未验证", signature ? @"已验证" : @"未验证",
                                 permission ? @"已验证" : @"未验证", ipc ? @"可用" : @"不可用"]}];
    [rows addObject:@{@"section": @"Helper 验证", @"title": @"备份提示", @"value": @"真实启停前须先生成操作前配置快照并通过校验；当前为只读预演。"}];

    // 文件信息。
    NSString *dylib = plugin.dylibPath ?: @"";
    [rows addObject:@{@"section": @"文件信息", @"title": @"dylib", @"value": dylib.length ? dylib : @"未定位到文件"}];
    if (dylib.length) {
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:dylib error:nil];
        NSNumber *size = attr[NSFileSize];
        [rows addObject:@{@"section": @"文件信息", @"title": @"文件大小", @"value": size ? [NSString stringWithFormat:@"%@ 字节", size] : @"未知"}];
    }
    [rows addObject:@{@"section": @"文件信息", @"title": @"MD5 / SHA256", @"value": @"预览阶段未读取二进制摘要"}];

    // 五组检查项。
    for (NSDictionary *check in self.preview.checks) {
        NSString *group = check[@"group"] ?: @"Unknown";
        NSString *status = [self statusText:check[@"status"]];
        [rows addObject:@{@"section": [NSString stringWithFormat:@"安全检查 · %@", group],
                          @"title": check[@"key"] ?: @"",
                          @"value": [NSString stringWithFormat:@"%@ · %@", status, check[@"detail"] ?: @""]}];
    }

    // 警告与潜在冲突。
    if (self.preview.warnings.count) {
        [rows addObject:@{@"section": @"警告与冲突", @"title": @"提示", @"value": [self.preview.warnings componentsJoinedByString:@"\n"]}];
    }

    // 安全边界说明。
    [rows addObject:@{@"section": @"安全边界", @"title": @"本次操作", @"value": @"仅在 FilterKit 内建立管理关系与预览记录"}];
    [rows addObject:@{@"section": @"安全边界", @"title": @"不会修改", @"value": @"不修改注入器配置文件、不执行插件启用/禁用、不连接未验证 Helper、不恢复系统文件"}];

    // 保存按钮（阻断态禁用）。
    BOOL blocked = [self.preview.result isEqualToString:FKPreviewResultBlocked];
    [rows addObject:@{@"section": @"保存", @"title": self.relationSaved ? @"管理关系已保存" : @"保存预览关系",
                      @"action": @(YES), @"blocked": @(blocked)}];

    self.rows = rows.copy;
}

- (NSString *)statusText:(NSString *)status {
    if ([status isEqualToString:FKCheckStatusPass]) return @"通过";
    if ([status isEqualToString:FKCheckStatusWarn]) return @"警告";
    if ([status isEqualToString:FKCheckStatusFail]) return @"未通过";
    return @"未知";
}

#pragma mark - 表格

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return [self orderedSections].count ?: 1;
}

- (NSArray<NSString *> *)orderedSections {
    NSMutableArray<NSString *> *ordered = [NSMutableArray array];
    for (NSDictionary *row in self.rows) {
        NSString *section = row[@"section"] ?: @"";
        if (![ordered containsObject:section]) [ordered addObject:section];
    }
    return ordered.copy;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray<NSString *> *sections = [self orderedSections];
    return section < (NSInteger)sections.count ? sections[section] : nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray<NSString *> *sections = [self orderedSections];
    NSString *target = sections[section];
    return [self.rows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"section == %@", target]].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"FKPreviewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    NSArray<NSString *> *sections = [self orderedSections];
    NSString *target = sections[indexPath.section];
    NSArray<NSDictionary *> *sectionRows = [self.rows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"section == %@", target]];
    NSDictionary *row = sectionRows[indexPath.row];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = [row[@"value"] description];
    cell.detailTextLabel.numberOfLines = 0;
    BOOL action = [row[@"action"] boolValue];
    BOOL blocked = [row[@"blocked"] boolValue];
    cell.accessoryType = action ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = (action && !blocked && !self.relationSaved) ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<NSString *> *sections = [self orderedSections];
    NSString *target = sections[indexPath.section];
    NSArray<NSDictionary *> *sectionRows = [self.rows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"section == %@", target]];
    NSDictionary *row = sectionRows[indexPath.row];
    if (![row[@"action"] boolValue] || self.relationSaved) return;

    // 阻断态：不保存管理关系，记录拒绝事件。
    if ([row[@"blocked"] boolValue]) {
        if (self.securityAuditManager) {
            [self.securityAuditManager recordEventType:FKSecurityEventTypeOperationDenied
                                                target:self.pluginID
                                                result:@"denied"
                                                 reason:@"兼容性检查未通过，阻断管理关系保存"
                                               evidence:@{@"app_bundle_id": self.appBundleID ?: @"", @"plugin_id": self.pluginID ?: @""}];
        }
        [self showMessage:@"存在不兼容项，已阻止保存管理关系。请查看检查结果。"];
        return;
    }

    [self saveAssociation];
}

/// 保存 FilterKit 管理关系；只记 association_created，不记录真实启用事件。
- (void)saveAssociation {
    FKAppPluginAssociation *association = [self.associationManager addAssociationForApp:self.appBundleID plugin:self.pluginID];
    if (!association) {
        [self showMessage:@"该关联已存在，无需重复保存。"];
        return;
    }
    self.relationSaved = YES;

    if (self.securityAuditManager) {
        [self.securityAuditManager recordEventType:FKSecurityEventTypeAssociationCreated
                                            target:association.associationID
                                            result:@"associated"
                                             reason:@"在 FilterKit 内建立 App ↔ 插件管理关系（未修改注入器配置）"
                                           evidence:@{@"app_bundle_id": self.appBundleID ?: @"", @"plugin_id": self.pluginID ?: @"", @"preview_id": self.preview.previewID ?: @""}];
    }
    [self rebuildRows];
    [self.tableView reloadData];
    [self showMessage:@"管理关系已保存。仅为 FilterKit 内记录，尚未写入注入器配置。"];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"配置预览" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
