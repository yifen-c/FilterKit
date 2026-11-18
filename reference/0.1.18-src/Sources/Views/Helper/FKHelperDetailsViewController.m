#import "FKHelperDetailsViewController.h"
#import "FKHelperDeploymentAssessment.h"
#import "FKHelperTransportAssessment.h"

static NSString *FKDetailStatusText(NSString *code, NSDictionary<NSString *, NSString *> *map) {
    return map[code] ?: @"未知";
}

static NSDictionary<NSString *, NSString *> *FKDetailIdentityMap(void) {
    return @{@"verified": @"已验证", @"mismatch": @"标识不符", @"incomplete": @"信息不完整", @"unknown": @"未知"};
}

static NSDictionary<NSString *, NSString *> *FKDetailManifestMap(void) {
    return @{@"verified": @"已验证", @"invalid": @"无效", @"unknown": @"未知", @"unavailable": @"未验证"};
}

static NSDictionary<NSString *, NSString *> *FKDetailSignatureMap(void) {
    return @{@"verified": @"已验证", @"invalid": @"无效", @"adhoc": @"临时签名", @"unsigned": @"未签名", @"unsupported": @"不支持", @"unknown": @"未知"};
}

static NSDictionary<NSString *, NSString *> *FKDetailIntegrityMap(void) {
    return @{@"verified": @"已验证", @"mismatch": @"不匹配", @"unavailable": @"不可用", @"unknown": @"未知"};
}

static NSDictionary<NSString *, NSString *> *FKDetailIPCMap(void) {
    return @{@"connected": @"已连接", @"disconnected": @"已断开", @"unavailable": @"不可用", @"timeout": @"超时", @"failed": @"失败", @"unknown": @"未知"};
}

/// 状态归类：ok 通过 / warn 证据不足或不支持 / bad 不符或失败。
static NSString *FKDetailKind(NSString *code) {
    NSSet<NSString *> *ok = [NSSet setWithArray:@[@"verified", @"connected"]];
    NSSet<NSString *> *bad = [NSSet setWithArray:@[@"mismatch", @"invalid", @"failed", @"timeout"]];
    if ([ok containsObject:code]) return @"ok";
    if ([bad containsObject:code]) return @"bad";
    return @"warn";
}

@interface FKHelperDetailsViewController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@end

@implementation FKHelperDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Helper 详情";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self rebuildRows];
    [self.tableView reloadData];
}

#pragma mark - 数据组装

- (void)rebuildRows {
    NSDictionary *snap = self.helperSnapshot ?: @{};
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];

    NSDictionary *helper = [snap[@"helper"] isKindOfClass:NSDictionary.class] ? snap[@"helper"] : @{};
    NSDictionary *identity = [snap[@"identity"] isKindOfClass:NSDictionary.class] ? snap[@"identity"] : @{};
    NSDictionary *manifest = [snap[@"manifest"] isKindOfClass:NSDictionary.class] ? snap[@"manifest"] : @{};
    NSDictionary *signature = [snap[@"signature"] isKindOfClass:NSDictionary.class] ? snap[@"signature"] : @{};
    NSDictionary *integrity = [snap[@"integrity"] isKindOfClass:NSDictionary.class] ? snap[@"integrity"] : @{};
    NSDictionary *ipc = [snap[@"ipc"] isKindOfClass:NSDictionary.class] ? snap[@"ipc"] : @{};
    NSDictionary *caps = [snap[@"capabilities"] isKindOfClass:NSDictionary.class] ? snap[@"capabilities"] : @{};

    // 区域一：身份（0.1.15 固定口径；无真实 Helper 时展示候选默认标识，不提升为可信）。
    NSString *helperID = helper[@"helperID"] ?: @"com.filterkit.helper";
    NSString *version = helper[@"version"] ?: @"0.1.18";
    NSString *buildID = helper[@"buildID"] ?: @"FKH-0118";
    [rows addObject:@{@"section": @"身份", @"title": @"Helper ID", @"value": helperID, @"kind": @"warn"}];
    [rows addObject:@{@"section": @"身份", @"title": @"Version", @"value": version, @"kind": @"warn"}];
    [rows addObject:@{@"section": @"身份", @"title": @"Build", @"value": buildID, @"kind": @"warn"}];
    [rows addObject:@{@"section": @"身份", @"title": @"Protocol", @"value": @"1.0", @"kind": @"warn"}];

    // 区域二：信任状态。
    NSString *identityCode = identity[@"status"] ?: @"unknown";
    NSString *manifestCode = manifest[@"status"] ?: @"unavailable";
    NSString *signatureCode = signature[@"status"] ?: @"unsupported";
    NSString *integrityCode = integrity[@"status"] ?: @"unknown";
    [rows addObject:@{@"section": @"信任状态", @"title": @"身份", @"value": FKDetailStatusText(identityCode, FKDetailIdentityMap()), @"kind": FKDetailKind(identityCode)}];
    [rows addObject:@{@"section": @"信任状态", @"title": @"发布清单", @"value": FKDetailStatusText(manifestCode, FKDetailManifestMap()), @"kind": FKDetailKind(manifestCode)}];
    [rows addObject:@{@"section": @"信任状态", @"title": @"签名", @"value": FKDetailStatusText(signatureCode, FKDetailSignatureMap()), @"kind": FKDetailKind(signatureCode)}];
    [rows addObject:@{@"section": @"信任状态", @"title": @"完整性", @"value": FKDetailStatusText(integrityCode, FKDetailIntegrityMap()), @"kind": FKDetailKind(integrityCode)}];

    // 区域三：通信。0.1.18 已实现 Unix Socket 适配器，但没有独立 Helper Listener 进程和 Endpoint 时仍不可连接。
    BOOL ipcVerified = [snap[@"ipc_verified"] boolValue];
    NSString *connection = ipc[@"text"] ?: FKDetailStatusText(ipc[@"code"] ?: @"unavailable", FKDetailIPCMap());
    NSDictionary *transportStatus = [snap[@"transport_status"] isKindOfClass:NSDictionary.class] ? snap[@"transport_status"] : @{};
    NSString *transportName = [transportStatus[@"kind"] isKindOfClass:NSString.class] ? transportStatus[@"kind"] : @"Unix Domain Socket（适配器已实现，端点未配置）";
    NSString *endpointName = [transportStatus[@"endpoint"] isKindOfClass:NSString.class] ? transportStatus[@"endpoint"] : @"Unavailable";
    [rows addObject:@{@"section": @"通信", @"title": @"Transport", @"value": transportName, @"kind": @"warn"}];
    [rows addObject:@{@"section": @"通信", @"title": @"Endpoint", @"value": endpointName, @"kind": @"warn"}];
    [rows addObject:@{@"section": @"通信", @"title": @"Connection", @"value": connection, @"kind": FKDetailKind(ipc[@"code"] ?: @"unavailable")}];
    NSString *peerText = [transportStatus[@"peerStatus"] isKindOfClass:NSString.class] ? transportStatus[@"peerStatus"] : (ipcVerified ? @"Verified" : @"Unverified");
    [rows addObject:@{@"section": @"通信", @"title": @"Peer", @"value": peerText, @"kind": ipcVerified ? @"ok" : @"warn"}];

    // 区域四：能力。写能力键一律标禁止；只读能力按证据展示可用 / 不可用。
    NSSet<NSString *> *writeKeys = [NSSet setWithArray:@[@"plugin.enable", @"plugin.disable", @"config.write", @"filter.modify", @"file.restore"]];
    NSArray<NSDictionary *> *capRows = @[
        @{@"title": @"本地检查", @"key": @"local.inspect"},
        @{@"title": @"Helper 信息", @"key": @"helper.info"},
        @{@"title": @"插件列表", @"key": @"plugin.list"},
        @{@"title": @"配置读取", @"key": @"config.inspect"},
        @{@"title": @"插件启用", @"key": @"plugin.enable"},
        @{@"title": @"插件禁用", @"key": @"plugin.disable"},
        @{@"title": @"配置修改", @"key": @"config.write"}
    ];
    for (NSDictionary *cap in capRows) {
        NSString *key = cap[@"key"];
        BOOL on = [caps[key] boolValue];
        NSString *value;
        NSString *kind;
        if ([writeKeys containsObject:key]) {
            value = @"禁止";
            kind = @"bad";
        } else {
            value = on ? @"可用" : @"不可用";
            kind = on ? @"ok" : @"warn";
        }
        [rows addObject:@{@"section": @"能力", @"title": cap[@"title"], @"value": value, @"kind": kind}];
    }

    // 区域五：可信通信就绪度。没有独立验证证据时一律保持未就绪。
    NSDictionary *readiness = [snap[@"readiness"] isKindOfClass:NSDictionary.class] ? snap[@"readiness"] : @{};
    [rows addObject:@{@"section": @"可信通信就绪度", @"title": @"可信发布锚点", @"value": [readiness[@"releaseTrustStatus"] isKindOfClass:NSString.class] ? readiness[@"releaseTrustStatus"] : @"未配置", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"可信通信就绪度", @"title": @"Peer Credential", @"value": [readiness[@"peerCredentialStatus"] isKindOfClass:NSString.class] ? readiness[@"peerCredentialStatus"] : @"不可用", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"可信通信就绪度", @"title": @"Transport 证据", @"value": [readiness[@"transportStatus"] isKindOfClass:NSString.class] ? readiness[@"transportStatus"] : @"未就绪", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"可信通信就绪度", @"title": @"Real IPC", @"value": [readiness[@"realIPCReady"] boolValue] ? @"已验证" : @"不可用", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"可信通信就绪度", @"title": @"写操作", @"value": @"关闭", @"kind": @"bad"}];

    // 区域六：部署可行性。仅展示已提供证据，不执行部署或拉起服务。
    NSDictionary *deploymentEvidence = [snap[@"deployment_evidence"] isKindOfClass:NSDictionary.class]
        ? snap[@"deployment_evidence"] : @{};
    NSDictionary *deployment = [FKHelperDeploymentAssessment assessmentWithEvidence:deploymentEvidence];
    BOOL evidenceComplete = [deployment[@"deploymentStatus"] isEqualToString:@"feasibility_evidence_complete"];
    [rows addObject:@{@"section": @"部署可行性", @"title": @"评估状态",
                      @"value": evidenceComplete ? @"证据齐全，待人工审核" : @"未就绪",
                      @"kind": @"warn"}];
    [rows addObject:@{@"section": @"部署可行性", @"title": @"独立 Helper Target",
                      @"value": [deployment[@"helperTargetPresent"] boolValue] ? @"已提供证据" : @"未验证",
                      @"kind": @"warn"}];
    [rows addObject:@{@"section": @"部署可行性", @"title": @"Mach Service",
                      @"value": [deployment[@"machServiceObserved"] boolValue] ? @"已提供证据" : @"未验证",
                      @"kind": @"warn"}];
    [rows addObject:@{@"section": @"部署可行性", @"title": @"真实 IPC",
                      @"value": @"未开放", @"kind": @"bad"}];
    [rows addObject:@{@"section": @"部署可行性", @"title": @"特权启动 / 写操作",
                      @"value": @"禁止", @"kind": @"bad"}];
    NSArray<NSString *> *pendingEvidence = [deployment[@"unverifiedEvidence"] isKindOfClass:NSArray.class]
        ? deployment[@"unverifiedEvidence"] : @[];
    NSArray<NSString *> *invalidEvidence = [deployment[@"invalidEvidence"] isKindOfClass:NSArray.class]
        ? deployment[@"invalidEvidence"] : @[];
    NSArray<NSString *> *unknownEvidence = [deployment[@"unknownEvidenceKeys"] isKindOfClass:NSArray.class]
        ? deployment[@"unknownEvidenceKeys"] : @[];
    NSMutableArray<NSString *> *pendingLabels = [NSMutableArray array];
    NSDictionary<NSString *, NSString *> *evidenceNames = @{
        @"helper_target_built": @"独立 Helper 构建",
        @"trusted_signing_anchor": @"可信签名锚点",
        @"helper_signature_verified": @"Helper 签名验证",
        @"entitlements_separated_and_reviewed": @"独立权限审查",
        @"mach_service_observed": @"Mach Service 注册",
        @"peer_identity_verified": @"Peer 身份验证",
        @"transport_device_verified": @"真机 Transport",
        @"lifecycle_device_verified": @"生命周期验证",
        @"rootless_build_verified": @"Rootless arm64 验收",
        @"roothide_build_verified": @"RootHide arm64e 验收"
    };
    for (NSString *key in pendingEvidence) [pendingLabels addObject:evidenceNames[key] ?: key];
    for (NSString *key in invalidEvidence) [pendingLabels addObject:[NSString stringWithFormat:@"%@（类型错误）", evidenceNames[key] ?: key]];
    for (NSString *key in unknownEvidence) [pendingLabels addObject:[NSString stringWithFormat:@"%@（未知字段）", key]];
    if (pendingLabels.count > 0) {
        [rows addObject:@{@"section": @"部署可行性", @"title": @"待完成证据",
                          @"value": [pendingLabels componentsJoinedByString:@"、"], @"kind": @"warn"}];
    }

    // 区域六：传输安全模型。空证据默认未验证，不进行系统探测或连接。
    FKHelperTransportAssessmentEngine *transportEngine = [FKHelperTransportAssessmentEngine new];
    NSArray<FKHelperTransportAssessment *> *transportOptions = [transportEngine assessCandidatesWithEvidence:snap[@"transport_evidence"]];
    [rows addObject:@{@"section": @"传输安全模型", @"title": @"消息认证",
                      @"value": @"HMAC-SHA256 模型已实现；密钥分发未实现", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"传输安全模型", @"title": @"防重放",
                      @"value": @"会话级 Request ID / Nonce 校验已实现", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"传输安全模型", @"title": @"帧协议",
                      @"value": @"4 字节网络序长度头；最大 1 MiB", @"kind": @"warn"}];
    for (FKHelperTransportAssessment *option in transportOptions) {
        NSString *label = [option.candidate isEqualToString:@"mach_service"] ? @"Mach Service" : @"Unix Socket";
        NSString *value = option.eligible ? @"证据齐备，待真机审核" : [NSString stringWithFormat:@"未验证：%@", [option.missingEvidence componentsJoinedByString:@"、"]];
        [rows addObject:@{@"section": @"传输安全模型", @"title": label, @"value": value, @"kind": @"warn"}];
    }
    [rows addObject:@{@"section": @"传输安全模型", @"title": @"真实连接",
                      @"value": @"未实现 / 未连接", @"kind": @"bad"}];
    [rows addObject:@{@"section": @"认证握手", @"title": @"会话密钥派生",
                      @"value": @"HKDF-SHA256 模型已实现；尚未接入可信握手", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"认证握手", @"title": @"密钥生命周期",
                      @"value": @"内存生成 / 到期 / 撤销；不持久化、不跨进程分发", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"认证握手", @"title": @"协议协商",
                      @"value": @"严格版本交集；主版本不兼容时拒绝", @"kind": @"warn"}];

    [rows addObject:@{@"section": @"认证握手", @"title": @"双向密钥确认",
                      @"value": @"已实现角色域分离 HMAC 确认模型；未接入真实对端", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"认证握手", @"title": @"握手状态机",
                      @"value": @"Peer → 协商 → 转录 → 派生 → 双向确认；缺证据拒绝推进", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"认证握手", @"title": @"Peer 绑定",
                      @"value": @"绑定 Helper ID / Build ID / 凭据摘要；凭据采集未接入", @"kind": @"warn"}];
    [rows addObject:@{@"section": @"认证握手", @"title": @"统一认证会话",
                      @"value": @"本地协调模型 · 仅只读 · 未接入真实 IPC"}];
    [rows addObject:@{@"section": @"认证握手", @"title": @"会话生命周期",
                      @"value": @"最大寿命与空闲超时；未接入真实连接", @"kind": @"warn"}];

    // 拒绝原因（如有），只读留证。
    NSArray<NSString *> *reasons = [snap[@"reasons"] isKindOfClass:NSArray.class] ? snap[@"reasons"] : @[];
    if (reasons.count > 0) {
        [rows addObject:@{@"section": @"能力", @"title": @"拒绝原因", @"value": [reasons componentsJoinedByString:@"；"], @"kind": @"warn"}];
    }

    self.rows = rows.copy;
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
    static NSString *reuse = @"FKHelperDetailCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuse];
    NSArray<NSString *> *sections = [self orderedSections];
    NSString *target = sections[indexPath.section];
    NSArray<NSDictionary *> *sectionRows = [self.rows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"section == %@", target]];
    NSDictionary *row = sectionRows[indexPath.row];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = row[@"value"];
    cell.detailTextLabel.numberOfLines = 0;
    NSString *kind = row[@"kind"] ?: @"warn";
    if ([kind isEqualToString:@"ok"]) {
        cell.detailTextLabel.textColor = UIColor.systemGreenColor;
    } else if ([kind isEqualToString:@"bad"]) {
        cell.detailTextLabel.textColor = UIColor.systemRedColor;
    } else {
        cell.detailTextLabel.textColor = UIColor.systemGrayColor;
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end
