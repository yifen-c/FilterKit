#import "FKHelperReportTests.h"
#import "FKHelperTrustEvaluator.h"
#import "FKHelperTrust.h"

@implementation FKHelperReportTests

+ (NSUInteger)checkCount { return 12; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // 空候选报告：0.1.15 未发现真实 Helper，所有可信结论保守降级。
    FKHelperTrustReport *report = [FKHelperTrustEvaluator evaluateCandidates:@[] store:nil];
    NSDictionary *json = report.JSONDictionary;

    // REP801：报告携带 schemaVersion 2。
    if (![json[@"schemaVersion"] isEqual:@(2)]) {
        [failures addObject:@"REP801 报告 schemaVersion 应为 2"];
    }

    // REP802：helper 分层携带稳定标识、版本与构建标识。
    NSDictionary *helper = [json[@"helper"] isKindOfClass:NSDictionary.class] ? json[@"helper"] : nil;
    if (!helper || ![helper[@"helperID"] isEqualToString:@"com.filterkit.helper"] ||
        ![helper[@"buildID"] isEqualToString:@"FKH-0118"] || helper[@"version"] == nil) {
        [failures addObject:@"REP802 helper 分层应携带 helperID/version/buildID 默认口径"];
    }

    // REP803：发现/身份/清单/签名/完整性/IPC 分层段均为字典。
    for (NSString *key in @[@"discovery", @"identity", @"manifest", @"signature", @"integrity", @"ipc"]) {
        if (![json[key] isKindOfClass:NSDictionary.class]) {
            [failures addObject:[NSString stringWithFormat:@"REP803 报告应包含 %@ 分层段", key]];
        }
    }

    // REP804：清单状态默认 unavailable，不假定已取得可信发布清单。
    NSDictionary *manifest = [json[@"manifest"] isKindOfClass:NSDictionary.class] ? json[@"manifest"] : nil;
    if (![manifest[@"status"] isEqualToString:@"unavailable"]) {
        [failures addObject:@"REP804 无锚点时清单状态应为 unavailable"];
    }

    // REP805：能力映射覆盖本地检查、Helper 只读与写能力共八个键。
    NSDictionary *capabilities = [json[@"capabilities"] isKindOfClass:NSDictionary.class] ? json[@"capabilities"] : nil;
    NSArray<NSString *> *capKeys = @[@"local.inspect", @"helper.info", @"plugin.list", @"plugin.inspect",
                                    @"config.inspect", @"plugin.enable", @"plugin.disable", @"config.write"];
    BOOL keysComplete = capabilities != nil;
    for (NSString *key in capKeys) {
        if (capabilities[key] == nil) { keysComplete = NO; break; }
    }
    if (!keysComplete) {
        [failures addObject:@"REP805 capabilities 应覆盖八个只读/写能力键"];
    }

    // REP806：本地检查可用；Helper 侧只读与全部写能力默认禁止。
    if (![capabilities[@"local.inspect"] boolValue]) {
        [failures addObject:@"REP806 本地检查能力应默认可用"];
    }
    for (NSString *key in @[@"helper.info", @"plugin.list", @"plugin.inspect", @"config.inspect",
                            @"plugin.enable", @"plugin.disable", @"config.write"]) {
        if ([capabilities[key] boolValue]) {
            [failures addObject:[NSString stringWithFormat:@"REP806 能力 %@ 在未连接真实 Helper 时应为禁止", key]];
        }
    }

    // REP807：permissions 分层只读可用、写能力关闭。
    NSDictionary *permissions = [json[@"permissions"] isKindOfClass:NSDictionary.class] ? json[@"permissions"] : nil;
    if (!permissions || ![permissions[@"readOnly"] boolValue] || [permissions[@"write"] boolValue]) {
        [failures addObject:@"REP807 permissions 应为只读可用、写能力关闭"];
    }

    // REP808：真实操作锁定。
    if ([json[@"real_operation_allowed"] boolValue]) {
        [failures addObject:@"REP808 阶段一 realOperationAllowed 必须为 NO"];
    }

    // REP809：未验证身份不得记录为已验证。
    NSDictionary *identity = [json[@"identity"] isKindOfClass:NSDictionary.class] ? json[@"identity"] : nil;
    if ([identity[@"verified"] boolValue]) {
        [failures addObject:@"REP809 空候选身份不应记为已验证"];
    }

    // REP810：未通过场景输出机器可读原因码。
    if (![json[@"reason_codes"] isKindOfClass:NSArray.class] || [json[@"reason_codes"] count] == 0) {
        [failures addObject:@"REP810 未通过场景应输出原因码"];
    }

    // REP811：签名证据不得判为已验证。
    NSDictionary *signature = [json[@"signature"] isKindOfClass:NSDictionary.class] ? json[@"signature"] : nil;
    if ([signature[@"status"] isEqualToString:@"verified"]) {
        [failures addObject:@"REP811 阶段一签名不应判为 verified"];
    }

    // REP812：证据字典与检查时间可序列化。
    if (![json[@"evidence"] isKindOfClass:NSDictionary.class] ||
        ![json[@"checked_at"] isKindOfClass:NSString.class] || [json[@"checked_at"] length] == 0) {
        [failures addObject:@"REP812 证据与时间戳应可序列化"];
    }

    return failures.copy;
}

@end
