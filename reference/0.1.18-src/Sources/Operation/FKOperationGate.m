#import "FKOperationGate.h"
#import "FKManageModels.h"
#import "FKHelperTrust.h"
#import "FKOperationEligibility.h"
#import "FKOperationPolicy.h"

@implementation FKOperationCheck

+ (instancetype)checkWithID:(NSString *)checkID title:(NSString *)title reason:(NSString *)reason status:(FKPreflightStatus)status {
    FKOperationCheck *check = [self new];
    check.checkID = checkID;
    check.title = title;
    check.reason = reason;
    check.status = status;
    return check;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"check_id": self.checkID ?: @"",
        @"title": self.title ?: @"",
        @"reason": self.reason ?: @"",
        @"status": @(self.status)
    };
}

@end

@implementation FKOperationPreflight

+ (NSArray<FKOperationCheck *> *)checksForPlugin:(FKPluginModel *)model
                                        injector:(NSString *)injector
                                    helperReport:(FKHelperTrustReport *)helperReport
                                  backupAvailable:(BOOL)backupAvailable {
    NSMutableArray<FKOperationCheck *> *checks = [NSMutableArray array];

    // 插件身份：扫描结果中必须存在该插件。
    if (model) {
        [checks addObject:[FKOperationCheck checkWithID:@"identity" title:@"插件身份" reason:@"插件已在扫描结果中识别" status:FKPreflightStatusPassed]];
    } else {
        [checks addObject:[FKOperationCheck checkWithID:@"identity" title:@"插件身份" reason:@"插件不存在或未被扫描识别" status:FKPreflightStatusFailed]];
    }

    // 文件路径：dylib 或 Filter plist 至少有一个明确路径。
    BOOL hasPath = model.dylibPath.length > 0 || model.filterPath.length > 0;
    [checks addObject:[FKOperationCheck checkWithID:@"path" title:@"文件路径"
                                             reason:hasPath ? @"已定位插件文件路径" : @"缺少明确的 dylib / plist 路径"
                                             status:hasPath ? FKPreflightStatusPassed : FKPreflightStatusFailed]];

    // 软件包归属。
    BOOL hasOwner = model.packageID.length > 0;
    [checks addObject:[FKOperationCheck checkWithID:@"ownership" title:@"软件包归属"
                                              reason:hasOwner ? [NSString stringWithFormat:@"归属包：%@", model.packageID] : @"无法追溯软件包归属"
                                              status:hasOwner ? FKPreflightStatusPassed : FKPreflightStatusWarning]];

    // 注入器识别。
    BOOL hasInjector = injector.length > 0;
    [checks addObject:[FKOperationCheck checkWithID:@"injector" title:@"注入器兼容性"
                                              reason:hasInjector ? [NSString stringWithFormat:@"识别到注入器：%@", injector] : @"未识别到注入器"
                                              status:hasInjector ? FKPreflightStatusPassed : FKPreflightStatusUnknown]];

    // 插件格式完整性。
    BOOL formatOK = [model.fileStatus isEqualToString:@"complete"];
    [checks addObject:[FKOperationCheck checkWithID:@"format" title:@"插件格式"
                                              reason:formatOK ? @"dylib 与 plist 配对完整" : [NSString stringWithFormat:@"文件配对状态：%@", model.fileStatus ?: @"unknown"]
                                              status:formatOK ? FKPreflightStatusPassed : FKPreflightStatusWarning]];

    // 操作方法：当前注入器对应的启停机制尚未验证，保守标 Unknown。
    [checks addObject:[FKOperationCheck checkWithID:@"method" title:@"操作方法"
                                              reason:@"当前注入器的插件管理方式尚未确认，未验证可执行的启停机制"
                                              status:FKPreflightStatusUnknown]];

    // 备份可用性。
    [checks addObject:[FKOperationCheck checkWithID:@"backup" title:@"操作前备份"
                                              reason:backupAvailable ? @"可在操作前创建文件备份" : @"备份不可用，禁止高风险操作"
                                              status:backupAvailable ? FKPreflightStatusPassed : FKPreflightStatusWarning]];

    // 影响可评估：Filter 规则可解析。
    BOOL impactAssessable = model.filter != nil;
    [checks addObject:[FKOperationCheck checkWithID:@"impact" title:@"操作影响"
                                              reason:impactAssessable ? @"已解析 Filter 规则，可评估关联范围" : @"规则不可解析，影响范围无法评估"
                                              status:impactAssessable ? FKPreflightStatusPassed : FKPreflightStatusUnknown]];

    // Helper 安全门槛：身份 / 签名 / 权限 / IPC 综合结论。
    [checks addObject:[self helperTrustCheckWithReport:helperReport]];

    return checks.copy;
}

+ (FKOperationCheck *)helperTrustCheckWithReport:(FKHelperTrustReport *)report {
    if (!report) {
        return [FKOperationCheck checkWithID:@"helper_trust" title:@"RootHelper 安全验证"
                                      reason:@"尚未评估 Helper 身份、签名、权限与 IPC" status:FKPreflightStatusUnknown];
    }
    NSString *reason = [report.reasons componentsJoinedByString:@"；"] ?: @"";
    switch (report.state) {
        case FKHelperTrustStateOperationReady:
            return [FKOperationCheck checkWithID:@"helper_trust" title:@"RootHelper 安全验证" reason:@"身份、签名、权限与 IPC 均已通过" status:FKPreflightStatusPassed];
        case FKHelperTrustStateRejected:
            return [FKOperationCheck checkWithID:@"helper_trust" title:@"RootHelper 安全验证" reason:reason status:FKPreflightStatusBlocked];
        case FKHelperTrustStateNotFound:
            return [FKOperationCheck checkWithID:@"helper_trust" title:@"RootHelper 安全验证" reason:@"未发现 RootHelper" status:FKPreflightStatusUnknown];
        default:
            return [FKOperationCheck checkWithID:@"helper_trust" title:@"RootHelper 安全验证" reason:reason status:FKPreflightStatusUnknown];
    }
}

+ (BOOL)isOperationEligible:(NSArray<FKOperationCheck *> *)checks {
    for (FKOperationCheck *check in checks) {
        if (check.status == FKPreflightStatusFailed || check.status == FKPreflightStatusBlocked) return NO;
    }
    return YES;
}

+ (FKOperationGate)gateForChecks:(NSArray<FKOperationCheck *> *)checks {
    BOOL hasBlock = NO;
    BOOL hasUnknown = NO;
    BOOL helperReady = NO;
    for (FKOperationCheck *check in checks) {
        if (check.status == FKPreflightStatusFailed || check.status == FKPreflightStatusBlocked) hasBlock = YES;
        if (check.status == FKPreflightStatusUnknown) hasUnknown = YES;
        if ([check.checkID isEqualToString:@"helper_trust"] && check.status == FKPreflightStatusPassed) helperReady = YES;
    }
    if (hasBlock) return FKOperationGateBlocked;
    if (!hasUnknown && helperReady) return FKOperationGateEnabled;
    return FKOperationGatePreviewOnly;
}

+ (NSString *)gateText:(FKOperationGate)gate {
    switch (gate) {
        case FKOperationGateBlocked: return @"已阻断：不满足受控操作条件";
        case FKOperationGateEnabled: return @"准入就绪：可执行指定操作";
        case FKOperationGatePreviewOnly: return @"只读预演：真实操作待安全门槛通过后开放";
    }
    return @"只读预演";
}

+ (FKOperationEligibility *)eligibilityForPlugin:(FKPluginModel *)plugin
                                        operation:(FKOperationType)operation
                                   environmentOK:(BOOL)environmentOK
                                injectorCompatible:(BOOL)injectorCompatible
                                     helperReport:(FKHelperTrustReport *)helperReport
                                   backupAvailable:(BOOL)backupAvailable
                                    userAuthorized:(BOOL)userAuthorized {
    return [self evaluateOperationForPlugin:plugin appBundleID:nil operation:operation
                              environmentOK:environmentOK injectorCompatible:injectorCompatible
                                  injector:nil helperReport:helperReport
                           backupAvailable:backupAvailable backupValid:backupAvailable
                                 scopeClear:YES auditWritable:YES userAuthorized:userAuthorized];
}

+ (NSString *)reasonCodeForCheckID:(NSString *)checkID status:(FKPreflightStatus)status {
    switch (status) {
        case FKPreflightStatusFailed:
        case FKPreflightStatusBlocked:
            break;
        default:
            return nil;
    }
    if ([checkID isEqualToString:@"identity"]) return @"target_unknown";
    if ([checkID isEqualToString:@"app_identity"]) return @"target_unknown";
    if ([checkID isEqualToString:@"helper_identity"]) return @"helper_untrusted";
    if ([checkID isEqualToString:@"helper_signature"]) return @"signature_invalid";
    if ([checkID isEqualToString:@"ipc"]) return @"ipc_unavailable";
    if ([checkID isEqualToString:@"protocol_version"]) return @"protocol_mismatch";
    if ([checkID isEqualToString:@"injector"]) return @"unsupported_injector";
    if ([checkID isEqualToString:@"injector_compatibility"]) return @"unsupported_injector";
    if ([checkID isEqualToString:@"scope"]) return @"shared_config_ambiguous";
    if ([checkID isEqualToString:@"backup"]) return @"backup_failed";
    if ([checkID isEqualToString:@"backup_verified"]) return @"backup_corrupted";
    if ([checkID isEqualToString:@"authorization"]) return @"authorization_missing";
    if ([checkID isEqualToString:@"audit"]) return @"audit_unavailable";
    return nil;
}

+ (FKOperationDecision)decisionForChecks:(NSArray<FKOperationCheck *> *)checks
                                   policy:(FKOperationPolicy *)policy {
    BOOL hasBlock = NO;
    BOOL hasFailed = NO;
    BOOL hasUnknown = NO;
    BOOL hasUnsupported = NO;
    BOOL allPassed = YES;

    for (FKOperationCheck *check in checks) {
        switch (check.status) {
            case FKPreflightStatusPassed:
                break;
            case FKPreflightStatusWarning:
                allPassed = NO;
                break;
            case FKPreflightStatusFailed:
                allPassed = NO;
                hasFailed = YES;
                if ([check.checkID isEqualToString:@"injector"] || [check.checkID isEqualToString:@"injector_compatibility"]) {
                    hasUnsupported = YES;
                }
                break;
            case FKPreflightStatusUnknown:
                allPassed = NO;
                hasUnknown = YES;
                break;
            case FKPreflightStatusBlocked:
                allPassed = NO;
                hasBlock = YES;
                break;
        }
    }

    // 注入器不支持优先归为 Unsupported。
    if (hasUnsupported) return FKOperationDecisionUnsupported;
    if (hasBlock || hasFailed) return FKOperationDecisionDenied;
    // 策略本身不开放真实操作时，即使检查齐备也不允许进入 Allowed。
    if (allPassed && policy.allowsRealOperation) return FKOperationDecisionAllowed;
    if (hasUnknown) return FKOperationDecisionUnknown;
    return FKOperationDecisionUnknown;
}

+ (FKOperationEligibility *)evaluateOperationForPlugin:(FKPluginModel *)plugin
                                            appBundleID:(nullable NSString *)appBundleID
                                             operation:(FKOperationType)operation
                                         environmentOK:(BOOL)environmentOK
                                      injectorCompatible:(BOOL)injectorCompatible
                                              injector:(nullable NSString *)injector
                                          helperReport:(nullable FKHelperTrustReport *)helperReport
                                       backupAvailable:(BOOL)backupAvailable
                                          backupValid:(BOOL)backupValid
                                            scopeClear:(BOOL)scopeClear
                                         auditWritable:(BOOL)auditWritable
                                       userAuthorized:(BOOL)userAuthorized {
    NSMutableArray<FKOperationCheck *> *checks = [NSMutableArray array];

    // 复用既有基础检查：身份 / 路径 / 归属 / 注入器 / 格式 / 方法 / 备份 / 影响 / Helper 综合信任。
    [checks addObjectsFromArray:[self checksForPlugin:plugin injector:injector ?: @""
                                          helperReport:helperReport backupAvailable:backupAvailable]];

    // App 身份：目标 Bundle ID 必须明确；全局插件无单一目标时证据不足，不视为明确授权。
    BOOL appIdentityClear = appBundleID.length > 0;
    [checks addObject:[FKOperationCheck checkWithID:@"app_identity" title:@"App 身份"
                                              reason:appIdentityClear ? [NSString stringWithFormat:@"目标 App：%@", appBundleID] : @"目标 App 身份不明确"
                                              status:appIdentityClear ? FKPreflightStatusPassed : FKPreflightStatusFailed]];

    // 环境与注入器兼容性。
    [checks addObject:[FKOperationCheck checkWithID:@"environment" title:@"运行环境"
                                             reason:environmentOK ? @"环境已识别且兼容" : @"环境证据不足或暂不兼容"
                                             status:environmentOK ? FKPreflightStatusPassed : FKPreflightStatusUnknown]];
    [checks addObject:[FKOperationCheck checkWithID:@"injector_compatibility" title:@"注入器兼容性"
                                             reason:injectorCompatible ? @"注入器支持该插件的规则与注入方式" : @"注入器兼容性证据不足"
                                             status:injectorCompatible ? FKPreflightStatusPassed : FKPreflightStatusUnknown]];

    // Helper 分层验证：身份 / 签名 / IPC / 协议版本；无报告时各项证据不足。
    BOOL identityVerified = helperReport.identityVerified;
    BOOL signatureVerified = helperReport.signatureVerified;
    BOOL ipcVerified = helperReport.ipcVerified;
    [checks addObject:[FKOperationCheck checkWithID:@"helper_identity" title:@"Helper 身份"
                                              reason:identityVerified ? @"Helper 身份已验证" : @"Helper 身份尚未验证"
                                              status:identityVerified ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];
    [checks addObject:[FKOperationCheck checkWithID:@"helper_signature" title:@"Helper 签名"
                                              reason:signatureVerified ? @"签名证据可信" : @"签名证据不足或不可信"
                                              status:signatureVerified ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];
    [checks addObject:[FKOperationCheck checkWithID:@"ipc" title:@"IPC 通道"
                                              reason:ipcVerified ? @"IPC 协议已验证" : @"IPC 通道尚未验证或不可用"
                                              status:ipcVerified ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];
    // 发布清单：仅取得可信且已验证的清单结论才视为通过；0.1.15 无内置锚点，默认 unavailable 阻断。
    BOOL manifestVerified = [helperReport.manifestStatus isEqualToString:@"verified"];
    [checks addObject:[FKOperationCheck checkWithID:@"helper_manifest" title:@"发布清单"
                                              reason:manifestVerified ? @"可信发布清单已验证" : @"可信发布清单未取得或未验证"
                                              status:manifestVerified ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];
    // 协议版本：0.1.15 无可信协议版本证据，保守归 Unknown，不自动判兼容。
    [checks addObject:[FKOperationCheck checkWithID:@"protocol_version" title:@"协议版本"
                                              reason:@"尚未取得可信 Helper 的协议版本兼容证据"
                                              status:FKPreflightStatusUnknown]];

    // 目标配置可读取：Filter 规则或插件路径至少可被解析。
    BOOL targetReadable = plugin.filter != nil || plugin.dylibPath.length > 0 || plugin.filterPath.length > 0;
    [checks addObject:[FKOperationCheck checkWithID:@"target_readable" title:@"目标配置可读"
                                              reason:targetReadable ? @"已定位并解析目标配置" : @"目标配置无法读取"
                                              status:targetReadable ? FKPreflightStatusPassed : FKPreflightStatusUnknown]];

    // 配置范围：共享配置必须能明确全部受影响目标；范围不明禁止执行。
    [checks addObject:[FKOperationCheck checkWithID:@"scope" title:@"配置范围"
                                             reason:scopeClear ? @"受影响目标范围明确" : @"共享配置影响范围不明确"
                                             status:scopeClear ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];

    // 备份与备份校验。
    [checks addObject:[FKOperationCheck checkWithID:@"backup" title:@"操作前备份"
                                             reason:backupAvailable ? @"已在操作前创建配置/文件备份" : @"备份不可用，禁止高风险操作"
                                             status:backupAvailable ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];
    [checks addObject:[FKOperationCheck checkWithID:@"backup_verified" title:@"备份校验"
                                              reason:backupValid ? @"备份摘要重读校验通过" : @"备份校验未通过或未校验"
                                              status:backupValid ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];

    // 审计可写入：历史记录必须可在沙盒内追加。
    [checks addObject:[FKOperationCheck checkWithID:@"audit" title:@"审计可写"
                                             reason:auditWritable ? @"操作历史可可靠保存" : @"审计记录不可写入"
                                             status:auditWritable ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];

    // 用户授权：未明确授权属于必要条件缺失，直接阻断。
    [checks addObject:[FKOperationCheck checkWithID:@"authorization" title:@"用户授权"
                                             reason:userAuthorized ? @"已取得明确操作授权" : @"未取得明确操作授权"
                                             status:userAuthorized ? FKPreflightStatusPassed : FKPreflightStatusBlocked]];

    // 汇总资格、阻止原因与原因码。
    BOOL eligible = YES;
    BOOL hasBlock = NO;
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];
    NSMutableArray<NSString *> *reasonCodes = [NSMutableArray array];
    for (FKOperationCheck *check in checks) {
        if (check.status == FKPreflightStatusFailed || check.status == FKPreflightStatusBlocked) {
            eligible = NO;
            hasBlock = YES;
        }
        if (check.status != FKPreflightStatusPassed) {
            NSString *text = check.reason.length ? check.reason : check.title;
            if (text.length) [reasons addObject:text];
        }
        NSString *code = [self reasonCodeForCheckID:check.checkID status:check.status];
        if (code.length && ![reasonCodes containsObject:code]) [reasonCodes addObject:code];
    }

    FKOperationPolicy *policy = [FKOperationPolicy defaultPolicy];
    FKOperationDecision decision = [self decisionForChecks:checks policy:policy];

    FKOperationEligibility *eligibility = [FKOperationEligibility new];
    eligibility.checks = checks.copy;
    eligibility.policy = policy;
    eligibility.mode = policy.mode;
    eligibility.eligible = eligible;
    eligibility.decision = decision;
    eligibility.reasonCodes = reasonCodes.copy;
    eligibility.appBundleID = appBundleID;
    if (hasBlock || decision == FKOperationDecisionDenied) {
        eligibility.status = @"blocked";
    } else if (eligible && policy.allowsRealOperation) {
        eligibility.status = @"ready";
    } else {
        eligibility.status = @"preview";
    }
    eligibility.blockReasons = reasons.copy;
    return eligibility;
}

@end
