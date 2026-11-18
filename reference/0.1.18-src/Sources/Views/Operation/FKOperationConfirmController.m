#import "FKOperationConfirmController.h"
#import "FKOperationManager.h"
#import "FKAuditManager.h"
#import "FKBackupManager.h"
#import "FKHelperTrust.h"
#import "FKOperationGate.h"
#import "FKOperationEligibility.h"
#import "FKOperationModels.h"
#import "FKManageModels.h"

@interface FKOperationConfirmController ()
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, assign) FKOperationType operation;
@property (nonatomic, strong) FKOperationManager *operationManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
@property (nonatomic, strong) FKBackupManager *backupManager;
@property (nonatomic, strong) FKHelperTrustReport *trustReport;
@property (nonatomic, strong) FKPluginModel *model;
@property (nonatomic, copy) NSString *injector;
@property (nonatomic, copy) NSDictionary *preview;
@property (nonatomic, strong) FKOperationEligibility *eligibility;
@property (nonatomic, copy) NSArray<FKOperationCheck *> *checks;
@property (nonatomic, assign) FKOperationGate gate;
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@end

static NSString *FKCheckStatusText(FKPreflightStatus status) {
    switch (status) {
        case FKPreflightStatusPassed: return @"通过";
        case FKPreflightStatusWarning: return @"警告";
        case FKPreflightStatusFailed: return @"不满足";
        case FKPreflightStatusUnknown: return @"证据不足";
        case FKPreflightStatusBlocked: return @"已阻断";
    }
    return @"未知";
}

static NSString *FKDecisionText(FKOperationDecision decision) {
    switch (decision) {
        case FKOperationDecisionAllowed: return @"允许执行";
        case FKOperationDecisionDenied: return @"拒绝执行";
        case FKOperationDecisionNeedsConfirmation: return @"需人工额外确认";
        case FKOperationDecisionUnsupported: return @"不支持该操作";
        case FKOperationDecisionUnknown: return @"证据不足，暂缓";
    }
    return @"未知";
}

@implementation FKOperationConfirmController

- (instancetype)initWithPluginID:(NSString *)pluginID
                        operation:(FKOperationType)operation
                  operationManager:(FKOperationManager *)operationManager
                     auditManager:(FKAuditManager *)auditManager
                    backupManager:(FKBackupManager *)backupManager
                      trustReport:(FKHelperTrustReport *)trustReport
                            model:(FKPluginModel *)model
                         injector:(NSString *)injector {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _pluginID = pluginID;
        _operation = operation;
        _operationManager = operationManager;
        _auditManager = auditManager;
        _backupManager = backupManager;
        _trustReport = trustReport;
        _model = model;
        _injector = injector ?: @"";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.operation == FKOperationTypeEnable ? @"启用预演" : @"停用预演";
    self.preview = [self.operationManager previewForPluginID:self.pluginID operation:self.operation];
    // 0.1.15 完整准入评估：身份/App 身份/Helper 分层/IPC/协议/范围/备份/校验/兼容/审计/授权；
    // 环境/注入器兼容/用户授权未在预演中确认，保守按未满足处理，UI 不绕过闸门。
    NSString *targetApp = self.model.associatedBundleIDs.firstObject;
    self.eligibility = [FKOperationPreflight evaluateOperationForPlugin:self.model
                                                            appBundleID:targetApp
                                                             operation:self.operation
                                                         environmentOK:NO
                                                      injectorCompatible:NO
                                                              injector:self.injector
                                                          helperReport:self.trustReport
                                                       backupAvailable:(self.backupManager != nil)
                                                         backupValid:NO
                                                           scopeClear:YES
                                                        auditWritable:YES
                                                      userAuthorized:NO];
    self.checks = self.eligibility.checks;
    self.gate = FKGateFromEligibility(self.eligibility);
    [self buildRows];
}

/// 由结构化准入结论派生旧闸门枚举，供既有文案与阻断判断复用。
static FKOperationGate FKGateFromEligibility(FKOperationEligibility *eligibility) {
    if ([eligibility.status isEqualToString:@"blocked"]) return FKOperationGateBlocked;
    if ([eligibility.status isEqualToString:@"ready"]) return FKOperationGateEnabled;
    return FKOperationGatePreviewOnly;
}

- (void)buildRows {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    NSDictionary *p = self.preview ?: @{};

    // A. 操作目标
    [rows addObject:@{@"title":@"插件", @"value": self.model.name.length ? self.model.name : self.pluginID}];
    [rows addObject:@{@"title":@"版本", @"value": self.model.version.length ? self.model.version : @"未知"}];
    [rows addObject:@{@"title":@"软件包", @"value": self.model.packageID.length ? self.model.packageID : @"未知"}];
    NSString *targetFile = self.model.dylibPath.length ? self.model.dylibPath : (self.model.filterPath ?: @"无明确路径");
    [rows addObject:@{@"title":@"目标文件", @"value": targetFile}];
    NSString *targetApps = self.model.associatedBundleIDs.count ? [self.model.associatedBundleIDs componentsJoinedByString:@", "] : @"全局 / 未指定 App";
    [rows addObject:@{@"title":@"影响 App", @"value": targetApps}];
    [rows addObject:@{@"title":@"当前状态", @"value": p[@"current_status"] ?: @"未知"}];
    [rows addObject:@{@"title":@"目标状态", @"value": p[@"target_state"] ?: @""}];

    // Helper 分层验证状态：身份 / 签名 / 权限 / IPC 独立展示，任一未通过即不可视为可信通道。
    [rows addObject:@{@"title":@"Helper 身份", @"value": self.trustReport.identityVerified ? @"已验证" : @"未验证"}];
    [rows addObject:@{@"title":@"Helper 签名", @"value": self.trustReport.signatureVerified ? @"已验证" : @"未验证"}];
    [rows addObject:@{@"title":@"Helper 完整性", @"value": [FKHelperTrustReport integrityTextForStatus:self.trustReport.integrityStatus]}];
    [rows addObject:@{@"title":@"Helper 权限", @"value": self.trustReport.permissionVerified ? @"已验证" : @"未验证"}];
    [rows addObject:@{@"title":@"IPC 通道", @"value": self.trustReport.ipcVerified ? @"可用" : @"不可用 / 未验证"}];
    [rows addObject:@{@"title":@"备份可用性", @"value": self.backupManager ? @"可生成操作前备份" : @"无备份服务"}];

    // B. 安全检查项
    for (FKOperationCheck *check in self.checks) {
        NSString *detail = [NSString stringWithFormat:@"%@ · %@", FKCheckStatusText(check.status), check.reason ?: @""];
        [rows addObject:@{@"title": check.title ?: @"", @"value": detail, @"check_status": @(check.status)}];
    }

    // C. 预计操作影响
    NSArray *impact = [p[@"impact"] isKindOfClass:NSArray.class] ? p[@"impact"] : @[];
    if (impact.count) [rows addObject:@{@"title":@"预计影响", @"value": [impact componentsJoinedByString:@"\n"]}];

    // D. 操作结论：决策与原因码来自结构化准入结论，UI 不自行重新计算准入。
    NSArray<NSString *> *blockReasons = self.eligibility.blockReasons ?: @[];
    NSArray<NSString *> *reasonCodes = self.eligibility.reasonCodes ?: @[];
    [rows addObject:@{@"title":@"准入结论", @"value":FKDecisionText(self.eligibility.decision)}];
    if (reasonCodes.count) [rows addObject:@{@"title":@"拒绝原因码", @"value":[reasonCodes componentsJoinedByString:@", "]}];
    if (blockReasons.count) {
        [rows addObject:@{@"title":@"未通过 / 存疑原因", @"value":[blockReasons componentsJoinedByString:@"\n"]}];
    }
    [rows addObject:@{@"title":@"说明", @"value":@"本次为只读预演，尚未修改任何越狱文件；真实操作需全部安全门槛通过后开放。"}];

    // 确认动作行；非准入就绪时点击仅提示原因，不触发任何写操作。
    [rows addObject:@{@"title": self.operation == FKOperationTypeEnable ? @"确认启用" : @"确认停用", @"action":@(YES)}];
    self.rows = rows.copy;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section; return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"FKConfirm";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    NSDictionary *row = self.rows[indexPath.row];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = [row[@"value"] description];
    cell.detailTextLabel.numberOfLines = 0;
    if ([row[@"action"] boolValue]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.rows[indexPath.row];
    if (![row[@"action"] boolValue]) return;

    // 仅准入就绪且决策为允许才进入受控流程；0.1.15 默认停留在只读预演。
    BOOL gateReady = (self.gate == FKOperationGateEnabled);
    BOOL decisionAllowed = (self.eligibility.decision == FKOperationDecisionAllowed);
    if (!gateReady || !decisionAllowed) {
        NSArray<NSString *> *reasons = self.eligibility.blockReasons ?: @[];
        NSString *reason = reasons.count ? [reasons componentsJoinedByString:@"\n"] : [FKOperationPreflight gateText:self.gate];
        [self showAlertWithTitle:@"暂不可执行" message:reason];
        return;
    }
    void (^handler)(FKOperationResult *) = ^(FKOperationResult *result) {
        [self showAlertWithTitle:result.success ? @"操作成功" : @"操作未执行" message:result.message ?: @""];
        [self.tableView reloadData];
    };
    if (self.operation == FKOperationTypeEnable) {
        [self.operationManager enablePlugin:self.pluginID completion:handler];
    } else {
        [self.operationManager disablePlugin:self.pluginID completion:handler];
    }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
