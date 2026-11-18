#import "FKDetailController.h"
#import "FKAppManager.h"
#import "FKPluginManager.h"
#import "FKStateManager.h"
#import "FKOperationManager.h"
#import "FKAuditManager.h"
#import "FKBackupManager.h"
#import "FKHelperTrust.h"
#import "FKOperationModels.h"
#import "FKManageModels.h"
#import "FKHistoryController.h"
#import "FKOperationConfirmController.h"
#import "FKAssociationManager.h"
#import "FKInjectionPreviewManager.h"
#import "FKCompatibilityManager.h"
#import "FKAppPluginAssociation.h"
#import "FKSecurityAuditManager.h"
#import "FKSecurityEvent.h"
#import "FKAddPluginViewController.h"

@interface FKDetailController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@property (nonatomic, copy) NSString *detailTitle;
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, copy) NSString *appBundleID;
@property (nonatomic, copy) NSString *appName;
@end

@implementation FKDetailController

- (instancetype)initWithItem:(NSDictionary *)item mode:(NSString *)mode allPlugins:(NSArray<NSDictionary *> *)plugins {
    (void)plugins;
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        NSMutableArray *rows = [NSMutableArray array];
        if ([mode isEqualToString:@"apps"]) {
            NSString *bundleID = item[@"bundle_id"] ?: @"";
            self.appBundleID = bundleID;
            self.appName = item[@"name"] ?: @"App 详情";
            self.detailTitle = self.appName;
            [rows addObject:@{@"title":@"Bundle ID",@"value":bundleID}];
            [rows addObject:@{@"title":@"版本",@"value":[item[@"version"] length] ? item[@"version"] : @"未知"}];
            [rows addObject:@{@"title":@"版本来源",@"value":item[@"version_source"] ?: @"未知"}];
            [rows addObject:@{@"title":@"可执行文件",@"value":item[@"executable"] ?: @"未知"}];
            [rows addObject:@{@"title":@"Bundle 路径",@"value":item[@"bundle_path"] ?: @""}];

            // 注入摘要：严格区分静态规则关联与运行时注入结果。
            NSDictionary *summary = self.appManager ? [self.appManager injectionSummaryForApp:bundleID] : @{};
            NSString *state = summary[@"injection_state"] ?: @"none";
            NSString *stateText;
            if ([state isEqualToString:@"static_global"]) stateText = @"被全局规则覆盖（静态）";
            else if ([state isEqualToString:@"static_associated"]) stateText = @"静态规则已关联";
            else stateText = @"未关联插件";
            [rows addObject:@{@"title":@"注入状态",@"value":stateText}];
            [rows addObject:@{@"title":@"运行时注入",@"value":[summary[@"runtime_injection_verified"] boolValue] ? @"已验证" : @"未验证（无进程级证据）"}];

            // 三态严格区分：Associated（FilterKit 管理关系）/ Configured（注入器配置可验证）/ Active（运行时证据）。
            NSUInteger associatedCount = self.associationManager ? [self.associationManager associationsForApp:bundleID].count : 0;
            [rows addObject:@{@"title":@"已关联 Associated", @"value": associatedCount > 0 ? [NSString stringWithFormat:@"已关联 %lu 个插件", (unsigned long)associatedCount] : @"未建立管理关系"}];
            [rows addObject:@{@"title":@"已配置 Configured", @"value": @"需要验证（0.1.15 未读取注入器真实配置）"}];
            [rows addObject:@{@"title":@"已生效 Active", @"value": [summary[@"runtime_injection_verified"] boolValue] ? @"有运行时证据" : @"未确认（无运行时证据）"}];
            // 添加插件入口：进入选择插件 → 兼容性 → 配置预览流程。
            [rows addObject:@{@"title":@"+ 添加插件", @"value":@"选择已安装插件并生成配置预览", @"action":@(YES), @"operation":@"add_plugin"}];

            NSArray<FKPluginModel *> *linked = self.appManager ? [self.appManager pluginsForApp:bundleID] : @[];
            [rows addObject:@{@"title":@"关联插件",@"value":@(linked.count)}];
            for (FKPluginModel *plugin in linked) {
                [rows addObject:@{@"title":plugin.name.length ? plugin.name : plugin.pluginID,
                                  @"value":[NSString stringWithFormat:@"插件：%@\n来源：%@\n类型：%@", plugin.pluginID, plugin.source ?: @"unknown", plugin.associationType ?: @"unknown"]}];
            }
            // 汇总关联插件的静态 Filter 规则（只读展示，不代表运行时已注入）。
            NSMutableArray<NSString *> *ruleLines = [NSMutableArray array];
            for (FKPluginModel *plugin in linked) {
                NSString *label = plugin.name.length ? plugin.name : plugin.pluginID;
                if (plugin.filter.bundles.count) [ruleLines addObject:[NSString stringWithFormat:@"%@ → Bundles: %@", label, [plugin.filter.bundles componentsJoinedByString:@", "]]];
                if (plugin.filter.executables.count) [ruleLines addObject:[NSString stringWithFormat:@"%@ → Executables: %@", label, [plugin.filter.executables componentsJoinedByString:@", "]]];
            }
            if (ruleLines.count) [rows addObject:@{@"title":@"Filter 匹配规则",@"value":[ruleLines componentsJoinedByString:@"\n"]}];
            if ([summary[@"note"] length]) [rows addObject:@{@"title":@"说明",@"value":summary[@"note"]}];
        } else {
            FKPluginModel *model = [FKPluginModel modelWithDictionary:item];
            self.pluginModel = model;
            self.detailTitle = model.name.length ? model.name : @"插件详情";
            [rows addObject:@{@"title":@"插件 ID",@"value":model.pluginID}];
            [rows addObject:@{@"title":@"版本",@"value":model.version.length ? model.version : @"未知"}];
            [rows addObject:@{@"title":@"来源",@"value":model.source ?: @"unknown"}];
            [rows addObject:@{@"title":@"dpkg 包",@"value":model.packageID.length ? model.packageID : @"未知"}];
            [rows addObject:@{@"title":@"dylib 路径",@"value":model.dylibPath.length ? model.dylibPath : @"缺失"}];
            if (model.dylibPath.length) {
                NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:model.dylibPath error:nil];
                NSNumber *fileSize = fileAttr[NSFileSize];
                if (fileSize) [rows addObject:@{@"title":@"dylib 大小",@"value":[NSString stringWithFormat:@"%@ 字节", fileSize]}];
            }
            [rows addObject:@{@"title":@"plist 路径",@"value":model.filterPath.length ? model.filterPath : @"缺失"}];
            [rows addObject:@{@"title":@"文件状态",@"value":model.fileStatus ?: @"unknown"}];
            [rows addObject:@{@"title":@"完整性",@"value":model.integrityStatus ?: @"未知"}];
            [rows addObject:@{@"title":@"关联类型",@"value":model.associationType ?: @"unknown"}];

            // 管理关系关联的 App（区别于静态 Filter 匹配）；点击跳转对应 App 详情。
            NSArray<FKAppPluginAssociation *> *relations = self.associationManager ? [self.associationManager associationsForPlugin:model.pluginID] : @[];
            if (relations.count) {
                for (FKAppPluginAssociation *relation in relations) {
                    [rows addObject:@{@"title":@"关联 App", @"value":relation.appBundleID, @"action":@(YES), @"operation":@"open_app", @"target":relation.appBundleID}];
                }
            } else {
                [rows addObject:@{@"title":@"关联 App", @"value":@"暂无 FilterKit 管理关系"}];
            }

            // 状态识别区：关联 / 配置 / 运行三态独立；状态必须有证据来源，无证据归 Unknown。
            self.pluginID = model.pluginID;
            FKPluginState *state = self.stateManager ? [self.stateManager stateForPluginID:model.pluginID] : nil;
            if (state) {
                [rows addObject:@{@"title":@"关联状态", @"value":[FKPluginState associationText:state.associationStatus]}];
                [rows addObject:@{@"title":@"配置状态", @"value":[FKPluginState configurationText:state.configurationStatus]}];
                [rows addObject:@{@"title":@"运行状态", @"value":[FKPluginState runtimeText:state.runtimeStatus]}];
                if (state.compatibilityStatus.length) [rows addObject:@{@"title":@"兼容性", @"value":state.compatibilityStatus}];
                [rows addObject:@{@"title":@"备份状态", @"value":[FKPluginState backupText:state.backupStatus]}];
                [rows addObject:@{@"title":@"状态证据", @"value":state.evidence ?: @"无"}];
            }

            // 管理操作区：按钮门禁依据配置状态与 Helper 验证结论；0.1.15 Helper 未验证，真实操作禁止。
            BOOL helperVerified = self.trustReport.identityVerified && self.trustReport.signatureVerified && self.trustReport.ipcVerified;
            NSString *gateNote = helperVerified ? @"门禁待最终校验" : @"Helper 未验证 · 禁止真实操作";
            if (!state || state.configurationStatus == FKConfigurationStatusUnknown) {
                [rows addObject:@{@"title":@"当前状态无法确认", @"value":@"请先重新检测插件配置；状态未知时禁止操作"}];
            } else {
                BOOL currentlyEnabled = state.configurationStatus == FKConfigurationStatusEnabled;
                NSString *mainOp = currentlyEnabled ? @"disable" : @"enable";
                NSString *mainTitle = currentlyEnabled ? @"禁用插件" : @"启用插件";
                [rows addObject:@{@"title":mainTitle, @"value":gateNote, @"action":@(YES), @"operation":mainOp}];
            }
            [rows addObject:@{@"title":@"操作预览", @"value":@"查看当前/目标配置、影响范围与安全检查", @"action":@(YES), @"operation":@"preview"}];
            [rows addObject:@{@"title":@"备份插件", @"value":@"复制 dylib / plist 到 App 沙盒并校验摘要", @"action":@(YES), @"operation":@"backup"}];
            [rows addObject:@{@"title":@"操作历史", @"value":@"查看该插件的受控操作审计记录", @"action":@(YES), @"operation":@"history"}];
            if ([model.raw[@"description"] length]) [rows addObject:@{@"title":@"包描述",@"value":model.raw[@"description"]}];
            NSArray *rules = item[@"Rules"] ?: @[];
            for (NSDictionary *rule in rules) {
                [rows addObject:@{@"title":@"Bundles",@"value":[(rule[@"bundle_ids"] ?: @[]) componentsJoinedByString:@"\n"]}];
                [rows addObject:@{@"title":@"Executables",@"value":[(rule[@"executables"] ?: @[]) componentsJoinedByString:@"\n"]}];
                [rows addObject:@{@"title":@"Classes",@"value":[(rule[@"classes"] ?: @[]) componentsJoinedByString:@"\n"]}];
                NSArray *matchedExec = rule[@"matched_executables"] ?: @[];
                if (matchedExec.count) [rows addObject:@{@"title":@"已匹配可执行",@"value":[matchedExec componentsJoinedByString:@"\n"]}];
                [rows addObject:@{@"title":@"配置状态",@"value":rule[@"configuration_status"] ?: @"unknown"}];
                [rows addObject:@{@"title":@"协议验证",@"value":[rule[@"protocol_verified"] boolValue] ? @"已验证" : @"尚未通过 Loader 源码验证"}];
            }
            [rows addObject:@{@"title":@"归属证据",@"value":item[@"OwnershipEvidence"] ?: @{}}];
        }
        _rows = rows.copy;
    }
    return self;
}

- (void)viewDidLoad { [super viewDidLoad]; self.title = self.detailTitle; self.tableView.rowHeight = UITableViewAutomaticDimension; self.tableView.estimatedRowHeight = 60;
    // 记录 App 打开审计事件（仅浏览记录，不代表启用）。
    if (self.appBundleID.length && self.securityAuditManager) {
        [self.securityAuditManager recordEventType:FKSecurityEventTypeAppOpened
                                            target:self.appBundleID
                                            result:@"viewed"
                                             reason:@"用户打开 App 详情"
                                           evidence:@{@"app_bundle_id": self.appBundleID}];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;(void)section; return self.rows.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse=@"FKDetail"; UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    NSDictionary *row=self.rows[indexPath.row]; cell.textLabel.text=row[@"title"];
    id value=row[@"value"];
    if ([value isKindOfClass:NSDictionary.class] || [value isKindOfClass:NSArray.class]) {
        NSData *d=[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:nil];
        cell.detailTextLabel.text=d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : [value description];
    } else cell.detailTextLabel.text=[value description];
    cell.detailTextLabel.numberOfLines=0;
    if ([row[@"action"] boolValue]) {
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle=UITableViewCellSelectionStyleDefault;
    } else {
        cell.accessoryType=UITableViewCellAccessoryNone;
        cell.selectionStyle=UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row=self.rows[indexPath.row];
    if (![row[@"action"] boolValue]) return;
    NSString *operation = row[@"operation"] ?: @"";

    // App 详情 → 添加插件流程。
    if ([operation isEqualToString:@"add_plugin"]) {
        [self openAddPlugin];
        return;
    }
    // 插件详情 → 跳转关联 App 详情。
    if ([operation isEqualToString:@"open_app"]) {
        [self openAppDetailForBundleID:row[@"target"]];
        return;
    }

    if (!self.pluginID.length) return;

    if ([operation isEqualToString:@"history"]) {
        FKHistoryController *history = [FKHistoryController new];
        history.auditManager = self.auditManager;
        history.filterPluginID = self.pluginID;
        [self.navigationController pushViewController:history animated:YES];
        return;
    }
    if ([operation isEqualToString:@"backup"]) {
        [self performBackup];
        return;
    }
    if (!self.operationManager) {
        [self showAlertTitle:@"暂不可用" message:@"操作服务尚未就绪，请重新扫描后再试。"];
        return;
    }
    FKOperationType type;
    if ([operation isEqualToString:@"preview"]) {
        // 操作预览：按当前配置反推目标操作，进入只读预演确认页。
        FKPluginState *previewState = self.stateManager ? [self.stateManager stateForPluginID:self.pluginID] : nil;
        type = (previewState.configurationStatus == FKConfigurationStatusEnabled) ? FKOperationTypeDisable : FKOperationTypeEnable;
    } else {
        type = [operation isEqualToString:@"enable"] ? FKOperationTypeEnable : FKOperationTypeDisable;
    }
    FKPluginState *state = self.stateManager ? [self.stateManager stateForPluginID:self.pluginID] : nil;
    NSString *injector = state.injector ?: @"";
    FKOperationConfirmController *confirm = [[FKOperationConfirmController alloc] initWithPluginID:self.pluginID
                                                                                       operation:type
                                                                                 operationManager:self.operationManager
                                                                                    auditManager:self.auditManager
                                                                                   backupManager:self.backupManager
                                                                                     trustReport:self.trustReport
                                                                                           model:self.pluginModel
                                                                                        injector:injector];
    [self.navigationController pushViewController:confirm animated:YES];
}

#pragma mark - 流程跳转

/// 进入添加插件流程：选择插件 → 兼容性检查 → 配置预览。
- (void)openAddPlugin {
    if (!self.pluginManager) {
        [self showAlertTitle:@"暂不可用" message:@"插件数据尚未就绪，请重新扫描后再试。"];
        return;
    }
    FKAddPluginViewController *addPlugin = [[FKAddPluginViewController alloc] initWithAppBundleID:self.appBundleID appName:self.appName];
    addPlugin.pluginManager = self.pluginManager;
    addPlugin.appManager = self.appManager;
    addPlugin.associationManager = self.associationManager;
    addPlugin.previewManager = self.previewManager;
    addPlugin.compatibilityManager = self.compatibilityManager;
    addPlugin.auditManager = self.auditManager;
    addPlugin.securityAuditManager = self.securityAuditManager;
    addPlugin.trustReport = self.trustReport.JSONDictionary ?: @{};
    [self.navigationController pushViewController:addPlugin animated:YES];
}

/// 从插件详情跳转到关联 App 详情。
- (void)openAppDetailForBundleID:(NSString *)bundleID {
    if (!bundleID.length) return;
    FKAppModel *app = [self.appManager appForBundleID:bundleID];
    NSDictionary *item = app ? app.JSONDictionary : @{@"bundle_id": bundleID, @"name": bundleID};
    FKDetailController *detail = [[FKDetailController alloc] initWithItem:item mode:@"apps" allPlugins:@[]];
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

/// 异步执行只读文件备份：后台复制与校验摘要，进度与结果回到主线程提示并写入审计；不写入越狱目录、不覆盖旧备份。
- (void)performBackup {
    if (!self.backupManager) {
        [self showAlertTitle:@"备份失败" message:@"备份服务尚未就绪"];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.backupManager backupPluginAsync:self.pluginID progress:^(FKBackupResult *result) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *file = result.currentFile.length ? result.currentFile : @"manifest";
        NSUInteger percent = (NSUInteger)(result.progress * 100.0);
        strongSelf.navigationItem.title = [NSString stringWithFormat:@"备份中 %lu%% · %@", (unsigned long)percent, file];
    } completion:^(FKBackupResult *result, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.navigationItem.title = strongSelf.detailTitle;
        BOOL succeeded = (result.status == FKBackupStatusCompleted);
        NSString *reason = succeeded ? nil : (error.localizedDescription ?: @"未生成有效备份记录");
        NSString *helperStatus = strongSelf.trustReport ? @"discovered" : @"unverified";
        if (strongSelf.auditManager) {
            [strongSelf.auditManager recordBackupWithPluginID:strongSelf.pluginID
                                                     backupID:result.backupID
                                                    succeeded:succeeded
                                                       reason:reason
                                                 helperStatus:helperStatus];
        }
        if (succeeded) {
            NSString *msg = [NSString stringWithFormat:@"已备份 %lu 个文件到 App 沙盒，摘要已校验。\n备份 ID：%@",
                             (unsigned long)result.fileCount, result.backupID ?: @""];
            [strongSelf showAlertTitle:@"备份完成" message:msg];
        } else if (result.status == FKBackupStatusCancelled) {
            [strongSelf showAlertTitle:@"备份已取消" message:reason ?: @"未提交数据已清理"];
        } else {
            [strongSelf showAlertTitle:@"备份失败" message:reason ?: @"备份失败，未生成有效记录"];
        }
    }];
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
