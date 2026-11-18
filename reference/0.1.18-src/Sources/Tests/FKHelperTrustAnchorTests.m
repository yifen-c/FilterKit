#import "FKHelperTrustAnchorTests.h"
#import "FKHelperTrustAnchor.h"
@implementation FKHelperTrustAnchorTests
+ (NSUInteger)checkCount { return 9; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *f = [NSMutableArray array];
    NSData *key = [NSMutableData dataWithLength:32];
    FKHelperTrustAnchor *test = [[FKHelperTrustAnchor alloc] initWithKeyID:@"test-key-01" algorithm:@"ed25519" publicKeyData:key environment:@"test" testOnly:YES];
    if (![test isStructurallyValid]) [f addObject:@"TAN1701 合法测试锚点结构应有效"];
    if (test.isUsableForProduction) [f addObject:@"TAN1702 测试锚点不得用于生产"];
    FKHelperTrustAnchorStore *empty = [FKHelperTrustAnchorStore new];
    if (empty.hasProductionAnchor || empty.anchors.count != 0) [f addObject:@"TAN1703 默认仓库不得虚构生产公钥"];
    FKHelperTrustAnchorStore *store = [[FKHelperTrustAnchorStore alloc] initWithAnchors:@[test]];
    if (![store anchorForKeyID:@"test-key-01"]) [f addObject:@"TAN1704 已登记测试锚点应可查询"];
    if ([store productionAnchorForKeyID:@"test-key-01"]) [f addObject:@"TAN1705 测试锚点不得作为生产锚点返回"];
    FKHelperTrustAnchor *bad = [[FKHelperTrustAnchor alloc] initWithKeyID:@"bad key" algorithm:@"unknown" publicKeyData:[NSData data] environment:@"release" testOnly:NO];
    if ([bad isStructurallyValid]) [f addObject:@"TAN1706 非法 Key ID/算法/公钥应拒绝"];
    FKHelperTrustAnchorStore *dedup = [[FKHelperTrustAnchorStore alloc] initWithAnchors:@[test, test]];
    if (dedup.anchors.count != 1) [f addObject:@"TAN1707 重复 Key ID 应去重"];
    FKHelperTrustAnchor *callerRelease = [[FKHelperTrustAnchor alloc] initWithKeyID:@"caller-key" algorithm:@"ed25519" publicKeyData:key environment:@"release" testOnly:NO];
    FKHelperTrustAnchorStore *callerStore = [[FKHelperTrustAnchorStore alloc] initWithAnchors:@[callerRelease]];
    if (callerStore.hasProductionAnchor) [f addObject:@"TAN1708 调用方提供的 release 锚点不得成为生产信任根"];
    if (![store.JSONDictionary[@"anchors"] isKindOfClass:NSArray.class]) [f addObject:@"TAN1709 锚点报告应输出列表"];
    return f.copy;
}
@end
