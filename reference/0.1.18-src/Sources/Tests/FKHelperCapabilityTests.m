#import "FKHelperCapabilityTests.h"
#import "FKHelperCapabilities.h"
#import "FKHelperTrust.h"
#import "FKCapabilityEvaluator.h"

@implementation FKHelperCapabilityTests

+ (NSUInteger)checkCount { return 9; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    NSSet<NSString *> *readOnly = [FKHelperCapabilities readOnlyWhitelist];
    NSSet<NSString *> *write = [FKHelperCapabilities writeCapabilityBlacklist];

    // CAP801：只读白名单覆盖六个只读能力键。
    NSArray<NSString *> *readOnlyKeys = @[@"helper.info", @"helper.health", @"capabilities.list",
                                        @"plugin.list", @"plugin.inspect", @"config.inspect"];
    for (NSString *key in readOnlyKeys) {
        if (![readOnly containsObject:key]) [failures addObject:[NSString stringWithFormat:@"CAP801 只读白名单缺少 %@", key]];
    }

    // CAP802：写能力键全部不在只读白名单内。
    for (NSString *key in write) {
        if ([readOnly containsObject:key]) [failures addObject:[NSString stringWithFormat:@"CAP802 写能力 %@ 不应进入只读白名单", key]];
    }

    // CAP803：已登记的只读能力 supportsCapability 为 YES；未登记为 NO。
    FKHelperCapabilities *registered = [FKHelperCapabilities capabilitiesWithSet:[NSSet setWithArray:@[@"plugin.list"]]];
    if (![registered supportsCapability:@"plugin.list"]) [failures addObject:@"CAP803 已登记只读能力应被支持"];
    if ([registered supportsCapability:@"helper.info"]) [failures addObject:@"CAP803 未登记能力不应被支持"];

    // CAP804：纯只读集合 containsOnlyReadOnlyCapabilities 为 YES。
    FKHelperCapabilities *pureReadOnly = [FKHelperCapabilities capabilitiesWithSet:readOnly];
    if (![pureReadOnly containsOnlyReadOnlyCapabilities]) [failures addObject:@"CAP804 纯只读集合应判定为只读"];

    // CAP805：混入写能力的集合不得判定为纯只读。
    NSSet<NSString *> *mixed = [readOnly setByAddingObjectsFromSet:write];
    FKHelperCapabilities *mixedCaps = [FKHelperCapabilities capabilitiesWithSet:mixed];
    if ([mixedCaps containsOnlyReadOnlyCapabilities]) [failures addObject:@"CAP805 含写能力集合不应判定为纯只读"];

    FKCapabilityEvaluator *evaluator = [FKCapabilityEvaluator new];

    // CAP806：无可信报告时，只读能力也不得授权。
    if ([evaluator canPerformCapability:@"helper.info" trustReport:nil capabilities:registered]) {
        [failures addObject:@"CAP806 无信任报告时应拒绝能力"];
    }

    // CAP807：写能力键即使在模拟齐备报告下也必须拒绝。
    FKHelperTrustReport *simulated = [FKHelperTrustReport new];
    simulated.identityVerified = YES;
    simulated.manifestStatus = @"verified";
    simulated.signatureVerified = YES;
    simulated.signatureStatus = FKSignatureStatusValid;
    simulated.integrityStatus = FKHelperIntegrityVerified;
    simulated.permissionVerified = YES;
    simulated.permissionReadOnly = YES;
    simulated.permissionWrite = NO;
    simulated.ipcStatus = FKHelperIPCConnected;
    simulated.ipcVerified = YES;
    if ([evaluator canPerformCapability:@"plugin.enable" trustReport:simulated capabilities:registered]) {
        [failures addObject:@"CAP807 写能力必须被评估器拒绝"];
    }

    // CAP808：身份未验证时拒绝只读能力。
    FKHelperTrustReport *identityUnknown = [FKHelperTrustReport new];
    identityUnknown.identityVerified = NO;
    if ([evaluator canPerformCapability:@"plugin.list" trustReport:identityUnknown capabilities:registered]) {
        [failures addObject:@"CAP808 身份未验证时应拒绝能力"];
    }

    // CAP809：信任链部分齐备（身份通过但清单/完整性/对端缺失）仍拒绝；模拟齐备仅验证正向逻辑。
    FKHelperTrustReport *partial = [FKHelperTrustReport new];
    partial.identityVerified = YES;
    partial.manifestStatus = @"unavailable";
    partial.integrityStatus = FKHelperIntegrityUnknown;
    partial.ipcVerified = NO;
    if ([evaluator canPerformCapability:@"plugin.list" trustReport:partial capabilities:registered]) {
        [failures addObject:@"CAP809 信任链未齐备时应拒绝能力"];
    }
    if (![evaluator canPerformCapability:@"helper.info" trustReport:simulated capabilities:pureReadOnly]) {
        [failures addObject:@"CAP809 模拟齐备且能力已登记时评估器正向逻辑应放行（仅本地逻辑验证，不代表真机授权）"];
    }

    return failures.copy;
}

@end
