#import "FKHelperReadinessReportTests.h"
#import "FKHelperReadinessReport.h"
@implementation FKHelperReadinessReportTests
+ (NSUInteger)checkCount { return 8; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *f = [NSMutableArray array]; FKHelperReadinessEvaluator *e = [FKHelperReadinessEvaluator new];
    FKHelperReadinessReport *missing = [e reportForHelperID:@"" releaseTrust:nil peerCredential:nil transport:nil];
    if (missing.realIPCReady || missing.readOnlyOperationsAllowed || missing.writeOperationsAllowed) [f addObject:@"RPT1701 无证据不得开放任何操作"];
    if (![missing.helperIdentityStatus isEqualToString:@"missing"]) [f addObject:@"RPT1702 缺失 Helper ID 应标记 missing"];
    if (![missing.blockingReasons containsObject:@"helper_identity_missing"]) [f addObject:@"RPT1703 应报告 Helper 身份缺失"];
    FKHelperReadinessReport *declared = [e reportForHelperID:@"com.filterkit.helper" releaseTrust:nil peerCredential:nil transport:nil];
    if (![declared.helperIdentityStatus isEqualToString:@"declared_unverified"]) [f addObject:@"RPT1704 自报 Helper ID 不等于已验证"];
    if (declared.realIPCReady) [f addObject:@"RPT1705 缺少真实 IPC 证据不得 Ready"];
    NSDictionary *json = declared.JSONDictionary;
    if (![json[@"blockingReasons"] isKindOfClass:NSArray.class]) [f addObject:@"RPT1706 报告应输出阻断原因"];
    if ([json[@"writeOperationsAllowed"] boolValue]) [f addObject:@"RPT1707 写操作必须保持关闭"];
    if ([json[@"readOnlyOperationsAllowed"] boolValue]) [f addObject:@"RPT1708 真实只读能力必须保持关闭"];
    return f.copy;
}
@end
