#import "FKHelperTransportReadinessTests.h"
#import "FKHelperTransportReadiness.h"
@implementation FKHelperTransportReadinessTests
+ (NSUInteger)checkCount { return 9; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *f = [NSMutableArray array]; NSDate *now = [NSDate date];
    FKHelperTransportReadinessEvaluator *e = [FKHelperTransportReadinessEvaluator new];
    FKHelperTransportEvidence *unsupported = [FKHelperTransportEvidence unsupportedEvidence];
    FKHelperTransportReadiness *u = [e evaluateTransport:unsupported peerCredential:nil releaseTrust:nil atDate:now];
    if (u.ready || u.realTransportVerified) [f addObject:@"TRN1701 Unsupported Transport 不得就绪"];
    FKHelperTransportEvidence *mock = [FKHelperTransportEvidence mockEvidenceWithKind:@"mach_service" endpoint:@"com.filterkit.test" connected:YES date:now];
    if (mock.isProductionEvidence) [f addObject:@"TRN1702 Mock Transport 不得视为生产证据"];
    FKHelperTransportReadiness *m = [e evaluateTransport:mock peerCredential:nil releaseTrust:nil atDate:now];
    if (m.ready) [f addObject:@"TRN1703 Mock Transport 不得通过就绪评估"];
    if (![m.missingEvidence containsObject:@"production_transport_attestation"]) [f addObject:@"TRN1704 缺少生产 Transport 证明应列出原因"];
    FKHelperTransportEvidence *emptyEndpoint = [FKHelperTransportEvidence mockEvidenceWithKind:@"mach_service" endpoint:@"" connected:YES date:now];
    FKHelperTransportReadiness *ep = [e evaluateTransport:emptyEndpoint peerCredential:nil releaseTrust:nil atDate:now];
    if (![ep.missingEvidence containsObject:@"verified_endpoint"]) [f addObject:@"TRN1705 缺失端点应列出原因"];
    FKHelperTransportEvidence *stale = [FKHelperTransportEvidence mockEvidenceWithKind:@"unix_socket" endpoint:@"test.sock" connected:YES date:[now dateByAddingTimeInterval:-120]];
    FKHelperTransportReadiness *st = [e evaluateTransport:stale peerCredential:nil releaseTrust:nil atDate:now];
    if (![st.missingEvidence containsObject:@"fresh_transport_evidence"]) [f addObject:@"TRN1706 过期证据必须拒绝"];
    if ([m.JSONDictionary[@"ready"] boolValue]) [f addObject:@"TRN1707 JSON 不得报告 Mock 就绪"];
    if (unsupported.lifecycleVerified) [f addObject:@"TRN1708 不支持 Transport 不得伪造生命周期验证"];
    if (![m.reasonCode isEqualToString:@"required_evidence_missing"]) [f addObject:@"TRN1709 缺失证据原因码错误"];
    return f.copy;
}
@end
