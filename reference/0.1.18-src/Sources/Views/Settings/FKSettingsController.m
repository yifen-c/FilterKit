#import "FKSettingsController.h"
#import "FKScanner.h"
#import "FKPluginManager.h"
#import "FKAppManager.h"
#import "FKAuditManager.h"
#import "FKOperationManager.h"
#import "FKBackupManager.h"
#import "FKHelperTrust.h"
#import "FKOperationModels.h"
#import "FKBackupListController.h"
#import "FKHistoryController.h"

@implementation FKSettingsController

- (void)viewDidLoad { [super viewDidLoad]; self.title=@"设置"; self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; if (section==0) return 6; if (section==1) return 6; return 5;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return @[@"运行环境",@"扫描统计与完整性",@"安全边界"][section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse=@"FKSetting"; UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuse];
    cell.selectionStyle=UITableViewCellSelectionStyleNone; NSDictionary *env=self.report.environment ?: @{};
    NSDictionary *fs=self.report.filesystem ?: @{};
    NSArray *tests=self.report.tests ?: @[]; NSUInteger passed=0,failed=0,unknown=0;
    for (FKTestResult *t in tests) { if(t.state==FKTestStatePassed)passed++; else if(t.state==FKTestStateFailed)failed++; else unknown++; }
    if (indexPath.section==0) {
        NSArray *titles=@[@"系统版本",@"越狱根目录",@"注入器",@"注入器版本",@"扫描版本",@"环境兼容性"];
        NSDictionary *injector = [env[@"injector"] isKindOfClass:NSDictionary.class] ? env[@"injector"] : @{};
        id rootValue = env[@"jbroot"];
        NSString *rootText = [rootValue isKindOfClass:NSString.class] && [rootValue length] ? rootValue : @"未知";
        id versionValue = injector[@"version"];
        NSString *injectorVersion = [versionValue isKindOfClass:NSString.class] && [versionValue length] ? versionValue : @"未知";
        NSString *toolVersion = self.report.JSONDictionary[@"version"] ?: @"0.1.18";
        NSDictionary *envAssessment = [self.report.environmentAssessment isKindOfClass:NSDictionary.class] ? self.report.environmentAssessment : @{};
        NSDictionary *comp = [envAssessment[@"compatibility"] isKindOfClass:NSDictionary.class] ? envAssessment[@"compatibility"] : @{};
        NSString *compText = comp[@"state_text"] ?: @"未知";
        NSArray *values=@[env[@"ios_version"] ?: @"未知", rootText, injector[@"injector_type"] ?: @"未知", injectorVersion, toolVersion, compText];
        cell.textLabel.text=titles[indexPath.row]; cell.detailTextLabel.text=[values[indexPath.row] description];
    } else if (indexPath.section==1) {
        NSArray *titles=@[@"App 数量",@"插件数量",@"dpkg 包数量",@"验收结果",@"MD5 完整性分析",@"自动化测试"];
        NSDictionary *dpkgAnalysis = [fs[@"dpkg_analysis"] isKindOfClass:NSDictionary.class] ? fs[@"dpkg_analysis"] : @{};
        NSDictionary *integrity = [dpkgAnalysis[@"integrity"] isKindOfClass:NSDictionary.class] ? dpkgAnalysis[@"integrity"] : @{};
        NSDictionary *checksum = [integrity[@"checksum_analysis"] isKindOfClass:NSDictionary.class] ? integrity[@"checksum_analysis"] : @{};
        NSUInteger pluginTotal = self.pluginManager.allPlugins.count;
        NSString *pluginText = [NSString stringWithFormat:@"%lu（关联 %lu · 全局 %lu · 未匹配 %lu）",
                                 (unsigned long)pluginTotal, (unsigned long)self.pluginManager.associatedPlugins.count,
                                 (unsigned long)self.pluginManager.globalPlugins.count, (unsigned long)self.pluginManager.unmatchedPlugins.count];
        NSDictionary *testSummary = [self.report.testSummary isKindOfClass:NSDictionary.class] ? self.report.testSummary : @{};
        NSString *testText = [NSString stringWithFormat:@"%@；通过 %lu / 失败 %lu / 共 %lu",
                               testSummary[@"status"] ?: @"NotTested",
                               [testSummary[@"passed"] unsignedIntegerValue],
                               [testSummary[@"failed"] unsignedIntegerValue],
                               [testSummary[@"total"] unsignedIntegerValue]];
        NSArray *values=@[@(self.report.apps.count),pluginText,fs[@"dpkg_package_count"] ?: @0,[NSString stringWithFormat:@"通过 %lu / 失败 %lu / 未确认 %lu",(unsigned long)passed,(unsigned long)failed,(unsigned long)unknown], [NSString stringWithFormat:@"校验 %@；Mach-O %@（%.1f%%）；plist 复核 %@；硬失败 %@；未确认 %@", checksum[@"checked"] ?: @0, checksum[@"mach_o_mismatches"] ?: @0, [checksum[@"binary_mismatch_rate"] doubleValue] * 100.0, checksum[@"configuration_review_mismatches"] ?: @0, checksum[@"hard_failures"] ?: @0, checksum[@"not_confirmed"] ?: @0], testText];
        cell.textLabel.text=titles[indexPath.row]; cell.detailTextLabel.text=[values[indexPath.row] description];
    } else {
        NSArray *titles=@[@"运行模式",@"写入能力",@"Helper 信任状态",@"备份管理",@"操作历史"];
        NSString *trustText;
        if (self.trustReport) {
            NSString *signText;
            switch (self.trustReport.signatureStatus) {
                case FKSignatureStatusValid:
                case FKSignatureStatusVerified: signText = @"已验证"; break;
                case FKSignatureStatusInvalid: signText = @"无效"; break;
                case FKSignatureStatusAdHoc: signText = @"临时签名"; break;
                case FKSignatureStatusUnsigned: signText = @"未签名"; break;
                case FKSignatureStatusUnsupported: signText = @"不支持"; break;
                default: signText = @"未知"; break;
            }
            NSString *discoveryText = [FKHelperDiscovery statusTextForStatus:self.trustReport.discoveryStatus];
            NSString *identityText = [FKHelperTrustReport identityTextForStatus:self.trustReport.identityStatus];
            NSString *integrityText = [FKHelperTrustReport integrityTextForStatus:self.trustReport.integrityStatus];
            NSString *ipcText = [FKHelperIPCHandshake statusTextForStatus:self.trustReport.ipcStatus];
            trustText = [NSString stringWithFormat:@"发现：%@；身份：%@；签名：%@；完整性：%@；IPC：%@",
                         discoveryText, identityText, signText, integrityText, ipcText];
        } else {
            trustText = @"未发现 RootHelper 候选";
        }
        NSArray *values=@[@"只读扫描与分析",@"未启用：不启停、不安装卸载、不改 Filter",trustText,@"查看沙盒内文件备份与恢复预览",@"查看受控操作审计记录"];
        cell.textLabel.text=titles[indexPath.row]; cell.detailTextLabel.text=values[indexPath.row];
        BOOL navigable = (indexPath.row == 3 || indexPath.row == 4);
        cell.accessoryType = navigable ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        cell.selectionStyle = navigable ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 2) return;
    if (indexPath.row == 3) {
        FKBackupListController *backups = [[FKBackupListController alloc] init];
        backups.backupManager = self.backupManager;
        backups.pluginManager = self.pluginManager;
        [self.navigationController pushViewController:backups animated:YES];
        return;
    }
    if (indexPath.row == 4) {
        FKHistoryController *history = [FKHistoryController new];
        history.auditManager = self.auditManager;
        [self.navigationController pushViewController:history animated:YES];
    }
}

@end
