#import "FKMainViewController.h"
#import "FKScanner.h"
#import "FKPluginManager.h"
#import "FKAppManager.h"
#import "FKBackupManager.h"
#import "FKStateManager.h"
#import "FKOperationManager.h"
#import "FKAuditManager.h"
#import "FKSecurityAuditManager.h"
#import "FKSecurityEvent.h"
#import "FKTestRunner.h"
#import "FKHelperClient.h"
#import "FKHelperTrust.h"
#import "FKHelperTrustVerifier.h"
#import "FKHelperTrustEvaluator.h"
#import "FKHelperTrustStore.h"
#import "FKDataListController.h"
#import "FKImportController.h"
#import "FKSettingsController.h"
#import "FKHomeViewController.h"
#import "FKAssociationManager.h"
#import "FKInjectionPreviewManager.h"
#import "FKCompatibilityManager.h"

@interface FKMainViewController ()
@property (nonatomic, strong) FKScanReport *report;
@property (nonatomic, strong) FKPluginManager *pluginManager;
@property (nonatomic, strong) FKAppManager *appManager;
@property (nonatomic, strong) FKBackupManager *backupManager;
@property (nonatomic, strong) FKStateManager *stateManager;
@property (nonatomic, strong) FKOperationManager *operationManager;
@property (nonatomic, strong) FKAuditManager *auditManager;
@property (nonatomic, strong) FKSecurityAuditManager *securityAuditManager;
@property (nonatomic, copy) NSString *scanID;
@property (nonatomic, strong) FKHelperClient *helperClient;
@property (nonatomic, strong) FKHelperTrustReport *trustReport;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIBarButtonItem *refreshItem;
@property (nonatomic, strong) UIBarButtonItem *exportItem;
@property (nonatomic, strong) UIBarButtonItem *backupItem;
@property (nonatomic, strong) FKDataListController *appsController;
@property (nonatomic, strong) FKDataListController *pluginsController;
@property (nonatomic, strong) FKImportController *importController;
@property (nonatomic, strong) FKSettingsController *settingsController;
@property (nonatomic, strong) FKHomeViewController *homeController;
@property (nonatomic, strong) FKAssociationManager *associationManager;
@property (nonatomic, strong) FKInjectionPreviewManager *previewManager;
@property (nonatomic, strong) FKCompatibilityManager *compatibilityManager;
@end

@implementation FKMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    // 审计历史与 Helper 客户端跨多次扫描保留；不随重扫清空。
    self.auditManager = [FKAuditManager new];
    self.securityAuditManager = [FKSecurityAuditManager new];
    self.helperClient = [FKHelperClient new];
    // 0.1.6 管理框架：关联 / 预览 / 兼容性管理器，跨扫描保留并沙盒持久化。
    self.associationManager = [FKAssociationManager new];
    self.previewManager = [FKInjectionPreviewManager new];
    self.compatibilityManager = [FKCompatibilityManager new];
    self.homeController = [FKHomeViewController new];
    self.appsController = [[FKDataListController alloc] initWithMode:@"apps"];
    self.pluginsController = [[FKDataListController alloc] initWithMode:@"plugins"];
    self.settingsController = [FKSettingsController new];

    UINavigationController *(^nav)(UIViewController *, NSString *, NSString *, NSString *) =
    ^UINavigationController *(UIViewController *root, NSString *title, NSString *image, NSString *selected) {
        root.title = title;
        UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:root];
        n.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:[UIImage systemImageNamed:image] selectedImage:[UIImage systemImageNamed:selected]];
        return n;
    };
    self.viewControllers = @[
        nav(self.homeController, @"首页", @"house", @"house.fill"),
        nav(self.appsController, @"App", @"square.grid.2x2", @"square.grid.2x2.fill"),
        nav(self.pluginsController, @"插件", @"puzzlepiece", @"puzzlepiece.fill"),
        nav(self.settingsController, @"设置", @"gearshape", @"gearshape.fill")
    ];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.refreshItem = [[UIBarButtonItem alloc] initWithTitle:@"重新扫描" style:UIBarButtonItemStylePlain target:self action:@selector(runScan)];
    self.exportItem = [[UIBarButtonItem alloc] initWithTitle:@"导出报告" style:UIBarButtonItemStylePlain target:self action:@selector(exportReport)];
    self.backupItem = [[UIBarButtonItem alloc] initWithTitle:@"导出备份" style:UIBarButtonItemStylePlain target:self action:@selector(exportBackup)];
    self.appsController.navigationItem.leftBarButtonItem = self.refreshItem;
    self.settingsController.navigationItem.rightBarButtonItem = self.exportItem;
    self.settingsController.navigationItem.leftBarButtonItem = self.backupItem;
    [self runScan];
}

- (void)runScan {
    if (self.spinner.isAnimating) return;
    // 每次扫描生成独立 scan_id，审计事件与安全报告据此关联；跨扫描保留历史事件。
    self.scanID = [NSUUID UUID].UUIDString;
    [self.securityAuditManager recordEventType:FKSecurityEventTypeScanStarted
                                         target:self.scanID
                                         result:@"passed"
                                         reason:@"扫描开始"
                                       evidence:@{@"scope": @"read_only_preflight_only"}];
    [self.spinner startAnimating];
    self.appsController.navigationItem.titleView = self.spinner;
    self.pluginsController.navigationItem.titleView = self.spinner;
    self.appsController.navigationItem.leftBarButtonItem.enabled = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        FKScanReport *report = [[FKScanner new] runScan];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.report = report;
            self.pluginManager = [[FKPluginManager alloc] initWithPlugins:report.plugins ?: @[]];
            self.appManager = [[FKAppManager alloc] initWithApps:report.apps ?: @[] plugins:self.pluginManager.allPlugins];
            self.backupManager = [[FKBackupManager alloc] initWithReport:report];
            self.backupManager.auditManager = self.auditManager;
            NSDictionary *env = [report.environment isKindOfClass:NSDictionary.class] ? report.environment : @{};
            NSDictionary *injector = [env[@"injector"] isKindOfClass:NSDictionary.class] ? env[@"injector"] : @{};
            NSString *injectorType = injector[@"injector_type"] ?: @"";
            self.stateManager = [[FKStateManager alloc] initWithPlugins:self.pluginManager.allPlugins injector:injectorType];
            self.operationManager = [[FKOperationManager alloc] initWithPluginManager:self.pluginManager
                                                                       stateManager:self.stateManager
                                                                       auditManager:self.auditManager
                                                                       helperClient:self.helperClient
                                                                       backupManager:self.backupManager];
            // 依据只读预检候选生成 Helper 信任报告；不连接、不启动 Helper。
            // 0.1.5 改由新 TrustEvaluator 汇总身份/签名/权限/IPC 证据；无可信锚点时保守降级。
            NSArray<NSDictionary *> *helperCandidates = [self helperCandidatesFromReport:report];
            self.trustReport = [FKHelperTrustEvaluator evaluateCandidates:helperCandidates store:[FKHelperTrustStore new]];
            report.helperTrust = self.trustReport.JSONDictionary ?: @{};
            [self attachSecurityAuditToReport:report];
            // 两个列表页注入同一套 Manager 实例，保证从 App / 插件任一入口进入详情页功能一致。
            self.appsController.appManager = self.appManager;
            self.appsController.stateManager = self.stateManager;
            self.appsController.operationManager = self.operationManager;
            self.appsController.auditManager = self.auditManager;
            self.appsController.backupManager = self.backupManager;
            self.appsController.trustReport = self.trustReport;
            self.appsController.associationManager = self.associationManager;
            self.appsController.previewManager = self.previewManager;
            self.appsController.compatibilityManager = self.compatibilityManager;
            self.appsController.securityAuditManager = self.securityAuditManager;
            self.pluginsController.pluginManager = self.pluginManager;
            self.pluginsController.stateManager = self.stateManager;
            self.pluginsController.operationManager = self.operationManager;
            self.pluginsController.auditManager = self.auditManager;
            self.pluginsController.backupManager = self.backupManager;
            self.pluginsController.trustReport = self.trustReport;
            self.pluginsController.associationManager = self.associationManager;
            self.pluginsController.previewManager = self.previewManager;
            self.pluginsController.compatibilityManager = self.compatibilityManager;
            self.pluginsController.securityAuditManager = self.securityAuditManager;

            self.homeController.report = report;
            self.homeController.appManager = self.appManager;
            self.homeController.pluginManager = self.pluginManager;
            self.homeController.associationManager = self.associationManager;
            self.homeController.previewManager = self.previewManager;
            self.homeController.auditManager = self.auditManager;
            self.homeController.trustReport = self.trustReport.JSONDictionary ?: @{};
            [self.spinner stopAnimating];
            self.appsController.navigationItem.titleView = nil;
            self.pluginsController.navigationItem.titleView = nil;
            self.appsController.navigationItem.leftBarButtonItem.enabled = YES;
            [self.appsController applyReport:report];
            [self.pluginsController applyReport:report];
            [self.homeController applyReport:report];
            self.settingsController.report = report;
            self.settingsController.appManager = self.appManager;
            self.settingsController.pluginManager = self.pluginManager;
            self.settingsController.auditManager = self.auditManager;
            self.settingsController.operationManager = self.operationManager;
            self.settingsController.backupManager = self.backupManager;
            self.settingsController.trustReport = self.trustReport;
            self.settingsController.associationManager = self.associationManager;
            self.settingsController.previewManager = self.previewManager;
            [self.settingsController.tableView reloadData];
        });
    });
}

- (void)exportReport {
    if (!self.report) {
        [self showMessage:@"扫描尚未完成。"];
        return;
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.report.JSONDictionary options:NSJSONWritingPrettyPrinted error:&error];
    if (!data) { [self showMessage:error.localizedDescription ?: @"JSON 生成失败"]; return; }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"FilterKit-0.1.18-report.json"];
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) { [self showMessage:error.localizedDescription ?: @"报告写入失败"]; return; }
    // 记录报告导出事件并刷新安全报告快照，使本次导出也纳入审计链。
    [self.securityAuditManager recordEventType:FKSecurityEventTypeReportExport target:self.scanID ?: @"report" result:@"completed" reason:@"" evidence:@{@"file": @"FilterKit-0.1.18-report.json"}];
    self.report.securityReport = self.securityAuditManager.JSONDictionary ?: @{};
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) share.popoverPresentationController.barButtonItem = self.exportItem;
    [self presentViewController:share animated:YES completion:nil];
}

/// 导出只读备份（JSON + 分块 SHA-256 摘要）；不恢复、不写入越狱环境。
- (void)exportBackup {
    if (!self.backupManager) {
        [self showMessage:@"扫描尚未完成。"];
        return;
    }
    NSDictionary *backup = [self.backupManager createPluginBackup];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:backup options:NSJSONWritingPrettyPrinted error:&error];
    if (!data) { [self showMessage:error.localizedDescription ?: @"备份生成失败"]; return; }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"FilterKit-0.1.15-backup.json"];
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) { [self showMessage:error.localizedDescription ?: @"备份写入失败"]; return; }
    [self.securityAuditManager recordEventType:FKSecurityEventTypeBackup target:@"export-backup" result:@"completed" reason:@"" evidence:@{@"file": @"FilterKit-0.1.15-backup.json"}];
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) share.popoverPresentationController.barButtonItem = self.backupItem;
    [self presentViewController:share animated:YES completion:nil];
}

/// 汇总本轮扫描的环境/注入器/Helper/闸门结论到安全审计，生成安全报告并写回报告。
- (void)attachSecurityAuditToReport:(FKScanReport *)report {
    NSDictionary *env = [report.environmentAssessment isKindOfClass:NSDictionary.class] ? report.environmentAssessment : @{};
    NSDictionary *injector = [report.injectorAssessment isKindOfClass:NSDictionary.class] ? report.injectorAssessment : @{};
    NSDictionary *helper = [report.helperTrust isKindOfClass:NSDictionary.class] ? report.helperTrust : @{};

    // 环境评估事件：兼容性状态由证据保守派生，证据不足归 Unknown。
    NSDictionary *comp = [env[@"compatibility"] isKindOfClass:NSDictionary.class] ? env[@"compatibility"] : @{};
    NSString *envResult = comp[@"status"] ?: @"unknown";
    [self.securityAuditManager recordEventType:FKSecurityEventTypeEnvironment
                                        target:self.scanID
                                        result:envResult
                                         reason:comp[@"state_text"] ?: @""
                                       evidence:env];

    // 注入器识别事件：未识别或证据不足不臆断为已支持。
    NSString *injResult = [injector[@"detected"] boolValue] ? (injector[@"evidence_level"] ?: @"partial") : @"unknown";
    [self.securityAuditManager recordEventType:FKSecurityEventTypeInjector
                                        target:injector[@"injector_id"] ?: @""
                                        result:injResult
                                         reason:@""
                                       evidence:injector];

    // Helper 信任事件：状态机结论与原因逐条留证，不把未验证提升为可信。
    NSString *helperCode = [helper[@"state"] isKindOfClass:NSString.class] ? helper[@"state"] : @"unknown";
    NSArray *reasons = [helper[@"reasons"] isKindOfClass:NSArray.class] ? helper[@"reasons"] : @[];
    [self.securityAuditManager recordEventType:FKSecurityEventTypeHelperDiscover
                                        target:helper[@"path"] ?: @""
                                        result:helperCode
                                         reason:[reasons componentsJoinedByString:@"；"]
                                       evidence:helper];

    // 闸门快照：扫描级默认只读预演；逐插件准入在预演页由新 Gate 动态评估。
    NSDictionary *gateSnapshot = @{@"mode": @"preview_only", @"status": @"preview",
        @"note": @"0.1.15 默认只读预演；真实操作待身份、签名、权限、IPC、备份与授权等门槛全部通过后开放"};
    [self.securityAuditManager recordEventType:FKSecurityEventTypeGateEvaluation
                                        target:self.scanID
                                        result:@"preview"
                                         reason:gateSnapshot[@"note"]
                                       evidence:gateSnapshot];

    // 绑定结构化快照，生成含事件链与结论分布的安全报告。
    self.securityAuditManager.scanID = self.scanID;
    self.securityAuditManager.environment = env;
    self.securityAuditManager.injector = injector;
    self.securityAuditManager.helperTrust = helper;
    self.securityAuditManager.securityGate = gateSnapshot;

    // 实际运行四套件最小自检；数字来自 TestRunner，失败项在 suites 明细中保留原因。
    NSDictionary *testSummary = [FKTestRunner runSummary];
    self.securityAuditManager.testSummary = testSummary;
    [self.securityAuditManager recordEventType:FKSecurityEventTypeTestExecution
                                        target:self.scanID
                                        result:testSummary[@"status"] ?: @"unknown"
                                         reason:@""
                                       evidence:testSummary];

    [self.securityAuditManager recordEventType:FKSecurityEventTypeScanCompleted
                                        target:self.scanID
                                        result:@"passed"
                                         reason:@"扫描完成"
                                       evidence:@{@"apps": @(report.apps.count), @"plugins": @(report.plugins.count)}];

    report.securityReport = self.securityAuditManager.JSONDictionary ?: @{};
    report.testSummary = testSummary;
}

/// 从扫描报告的 RootHelper 预检结果中提取候选字典。
- (NSArray<NSDictionary *> *)helperCandidatesFromReport:(FKScanReport *)report {
    for (FKTestResult *result in report.tests ?: @[]) {
        if ([result.identifier isEqualToString:@"roothelper_preflight"]) {
            id candidates = result.payload[@"candidates"];
            return [candidates isKindOfClass:NSArray.class] ? candidates : @[];
        }
    }
    return @[];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"FilterKit" message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
