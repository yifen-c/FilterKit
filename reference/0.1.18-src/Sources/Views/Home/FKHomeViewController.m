#import "FKHomeViewController.h"
#import "FKScanner.h"
#import "FKAppManager.h"
#import "FKPluginManager.h"
#import "FKAssociationManager.h"
#import "FKInjectionPreviewManager.h"
#import "FKAuditManager.h"
#import "FKOperationModels.h"
#import "FKHelperDetailsViewController.h"

static NSString *FKHomeStatusText(NSString *code, NSDictionary<NSString *, NSString *> *map) {
    NSString *text = map[code];
    return text ?: @"未知";
}

static NSDictionary<NSString *, NSString *> *FKHomeIdentityMap(void) {
    return @{@"verified": @"已验证", @"mismatch": @"标识不符", @"incomplete": @"信息不完整", @"unknown": @"未知"};
}

static NSDictionary<NSString *, NSString *> *FKHomeSignatureMap(void) {
    return @{@"verified": @"已验证", @"invalid": @"无效", @"adhoc": @"临时签名", @"unsigned": @"未签名", @"unsupported": @"不支持", @"unknown": @"未知"};
}

static NSDictionary<NSString *, NSString *> *FKHomeIntegrityMap(void) {
    return @{@"verified": @"已验证", @"mismatch": @"不匹配", @"unavailable": @"不可用", @"unknown": @"未知"};
}

@interface FKHomeViewController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@end

@implementation FKHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"首页";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self rebuildRows];
    [self.tableView reloadData];
}

- (void)applyReport:(FKScanReport *)report {
    self.report = report;
    [self rebuildRows];
    [self.tableView reloadData];
}

#pragma mark - 数据组装

- (void)rebuildRows {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    FKScanReport *report = self.report;

    NSDictionary *env = [report.environment isKindOfClass:NSDictionary.class] ? report.environment : @{};
    NSDictionary *envAssess = [report.environmentAssessment isKindOfClass:NSDictionary.class] ? report.environmentAssessment : @{};
    NSDictionary *injector = [report.injectorAssessment isKindOfClass:NSDictionary.class] ? report.injectorAssessment : @{};
    NSDictionary *helper = [report.helperTrust isKindOfClass:NSDictionary.class] ? report.helperTrust : @{};

    // 设备与越狱环境卡片。
    NSString *jbType = envAssess[@"jailbreak_display_name"] ?: envAssess[@"jailbreak_type"] ?: env[@"jailbreak"] ?: @"未知";
    NSString *iosVersion = env[@"ios_version"] ?: @"未知";
    NSString *arch = env[@"architecture"] ?: @"未知";
    NSDictionary *comp = [envAssess[@"compatibility"] isKindOfClass:NSDictionary.class] ? envAssess[@"compatibility"] : @{};
    NSString *envState = comp[@"state_text"] ?: @"未知";

    [rows addObject:@{@"section": @"设备与环境", @"title": @"越狱环境", @"value": jbType}];
    [rows addObject:@{@"section": @"设备与环境", @"title": @"系统版本", @"value": iosVersion}];
    [rows addObject:@{@"section": @"设备与环境", @"title": @"设备架构", @"value": arch}];
    [rows addObject:@{@"section": @"设备与环境", @"title": @"环境检测", @"value": envState}];

    // Injector 卡片。
    NSString *injectorID = injector[@"injector_id"] ?: @"未识别";
    NSString *injectorVersion = [injector[@"version"] length] ? injector[@"version"] : @"未知";
    [rows addObject:@{@"section": @"注入器", @"title": @"Injector", @"value": [NSString stringWithFormat:@"%@ · %@", injectorID, injectorVersion]}];

    // Helper 安全状态：严格区分发现 / 身份 / 签名 / 完整性 / 权限；未验证不提升为可信。
    NSDictionary *discovery = [helper[@"discovery"] isKindOfClass:NSDictionary.class] ? helper[@"discovery"] : @{};
    NSDictionary *identityDict = [helper[@"identity"] isKindOfClass:NSDictionary.class] ? helper[@"identity"] : @{};
    NSDictionary *signatureDict = [helper[@"signature"] isKindOfClass:NSDictionary.class] ? helper[@"signature"] : @{};
    NSDictionary *integrityDict = [helper[@"integrity"] isKindOfClass:NSDictionary.class] ? helper[@"integrity"] : @{};
    NSDictionary *ipcDict = [helper[@"ipc"] isKindOfClass:NSDictionary.class] ? helper[@"ipc"] : @{};
    NSString *helperStateText = discovery[@"text"] ?: (helper[@"state_text"] ?: @"未验证");
    NSString *identity = FKHomeStatusText(identityDict[@"status"], FKHomeIdentityMap());
    NSString *signature = FKHomeStatusText(signatureDict[@"status"], FKHomeSignatureMap());
    NSString *integrity = FKHomeStatusText(integrityDict[@"status"], FKHomeIntegrityMap());
    NSString *ipc = [NSString stringWithFormat:@"%@ · 禁止真实操作", ipcDict[@"text"] ?: @"不可用"];
    [rows addObject:@{@"section": @"Helper 安全状态", @"title": @"发现状态", @"value": helperStateText}];
    [rows addObject:@{@"section": @"Helper 安全状态", @"title": @"身份验证", @"value": identity}];
    [rows addObject:@{@"section": @"Helper 安全状态", @"title": @"签名验证", @"value": signature}];
    [rows addObject:@{@"section": @"Helper 安全状态", @"title": @"完整性", @"value": integrity}];
    [rows addObject:@{@"section": @"Helper 安全状态", @"title": @"IPC / 操作权限", @"value": ipc}];
    [rows addObject:@{@"section": @"Helper 安全状态", @"title": @"查看详细报告", @"value": @"身份 · 信任 · 通信 · 能力", @"action": @"helper_details"}];

    // 扫描统计。
    NSUInteger appCount = report.apps.count;
    NSUInteger pluginCount = report.plugins.count;
    NSUInteger packageCount = [self countInFilesystem:report.filesystem key:@"packages"];
    NSUInteger filterCount = [self countInFilesystem:report.filesystem key:@"filters"];
    [rows addObject:@{@"section": @"扫描统计", @"title": @"App", @"value": @(appCount)}];
    [rows addObject:@{@"section": @"扫描统计", @"title": @"插件", @"value": @(pluginCount)}];
    [rows addObject:@{@"section": @"扫描统计", @"title": @"软件包", @"value": @(packageCount)}];
    [rows addObject:@{@"section": @"扫描统计", @"title": @"Filter", @"value": @(filterCount)}];

    // 最近活动：最近扫描 / 最近备份 / 最近预演（只读历史，不代表真实操作）。
    [rows addObjectsFromArray:[self recentActivityRows]];

    self.rows = rows.copy;
}

- (NSUInteger)countInFilesystem:(NSDictionary *)filesystem key:(NSString *)key {
    NSArray *array = [filesystem isKindOfClass:NSDictionary.class] ? filesystem[key] : nil;
    return [array isKindOfClass:NSArray.class] ? array.count : 0;
}

- (NSArray<NSDictionary *> *)recentActivityRows {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    NSArray<FKOperationRecord *> *records = self.auditManager.records;
    FKOperationRecord *latestBackup = nil;
    FKOperationRecord *latestPreview = nil;
    for (FKOperationRecord *record in records.reverseObjectEnumerator) {
        if ([record.operation isEqualToString:@"backup"] && !latestBackup) latestBackup = record;
        if (([record.operation isEqualToString:@"validate"] || [record.operation isEqualToString:@"preview"]) && !latestPreview) latestPreview = record;
    }
    [rows addObject:@{@"section": @"最近活动", @"title": @"最近扫描", @"value": self.report ? @"本轮扫描已完成" : @"尚未扫描"}];
    [rows addObject:@{@"section": @"最近活动", @"title": @"最近备份", @"value": [self activityTextForRecord:latestBackup fallback:@"暂无备份记录"]}];
    [rows addObject:@{@"section": @"最近活动", @"title": @"最近预演", @"value": [self activityTextForRecord:latestPreview fallback:@"暂无预演记录"]}];
    return rows.copy;
}

- (NSString *)activityTextForRecord:(FKOperationRecord *)record fallback:(NSString *)fallback {
    if (!record) return fallback;
    NSString *time = record.timestamp ? [NSDateFormatter localizedStringFromDate:record.timestamp dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle] : @"";
    return [NSString stringWithFormat:@"%@ · %@", record.result ?: @"unknown", time];
}

#pragma mark - 表格

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    NSMutableSet<NSString *> *sections = [NSMutableSet set];
    for (NSDictionary *row in self.rows) [sections addObject:row[@"section"] ?: @""];
    return sections.count ?: 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    NSArray<NSString *> *sections = [self orderedSections];
    return section < (NSInteger)sections.count ? sections[section] : nil;
}

- (NSArray<NSString *> *)orderedSections {
    NSMutableArray<NSString *> *ordered = [NSMutableArray array];
    for (NSDictionary *row in self.rows) {
        NSString *section = row[@"section"] ?: @"";
        if (![ordered containsObject:section]) [ordered addObject:section];
    }
    return ordered.copy;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray<NSString *> *sections = [self orderedSections];
    NSString *target = section < (NSInteger)sections.count ? sections[section] : @"";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"section == %@", target];
    return [self.rows filteredArrayUsingPredicate:pred].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"FKHomeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuse];
    NSArray<NSString *> *sections = [self orderedSections];
    NSString *target = sections[indexPath.section];
    NSArray<NSDictionary *> *sectionRows = [self.rows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"section == %@", target]];
    NSDictionary *row = sectionRows[indexPath.row];
    cell.textLabel.text = row[@"title"];
    id value = row[@"value"];
    cell.detailTextLabel.text = [value isKindOfClass:NSNumber.class] ? [value stringValue] : [value description];
    cell.detailTextLabel.numberOfLines = 0;
    BOOL isAction = [row[@"action"] isEqualToString:@"helper_details"];
    cell.accessoryType = isAction ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = isAction ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSString *> *sections = [self orderedSections];
    NSString *target = sections[indexPath.section];
    NSArray<NSDictionary *> *sectionRows = [self.rows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"section == %@", target]];
    NSDictionary *row = sectionRows[indexPath.row];
    if ([row[@"action"] isEqualToString:@"helper_details"]) {
        FKHelperDetailsViewController *details = [FKHelperDetailsViewController new];
        details.helperSnapshot = self.trustReport;
        [self.navigationController pushViewController:details animated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
