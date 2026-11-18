#import "FKHelperReleaseVerifierTests.h"
#import "FKHelperReleaseVerifier.h"
@implementation FKHelperReleaseVerifierTests
+ (NSUInteger)checkCount { return 8; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *f = [NSMutableArray array];
    FKHelperReleaseVerifier *verifier = [[FKHelperReleaseVerifier alloc] initWithAnchorStore:[FKHelperTrustAnchorStore new] signatureVerifier:nil];
    FKHelperReleaseVerificationResult *missing = [verifier verifyManifest:nil signature:nil expectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-0118" architecture:@"arm64e" actualSHA256:nil];
    if (missing.status != FKHelperReleaseVerificationUnavailable || missing.allowsTrustedRelease) [f addObject:@"REL1701 缺失 Manifest 应不可用"];
    NSDictionary *d = @{ @"schemaVersion": @1, @"product": @"FilterKit", @"component": @"FilterKitHelper", @"helperID": @"com.filterkit.helper", @"version": @"0.1.18", @"buildID": @"FKH-0118", @"protocolMajor": @1, @"protocolMinor": @0, @"artifacts": @[@{@"architecture": @"arm64e", @"sha256": [@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0]}], @"manifestKeyID": @"release-key", @"releaseStatus": @"development" };
    FKHelperTrustManifest *manifest = [FKHelperTrustManifest manifestFromDictionary:d];
    FKHelperReleaseVerificationResult *dev = [verifier verifyManifest:manifest signature:[NSData dataWithBytes:"x" length:1] expectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-0118" architecture:@"arm64e" actualSHA256:[@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0]];
    if (dev.status != FKHelperReleaseVerificationUnknown || ![dev.reasonCode isEqualToString:@"development_channel"]) [f addObject:@"REL1702 Development 通道不得验证为正式发布"];
    NSMutableDictionary *releaseDict = [d mutableCopy]; releaseDict[@"releaseStatus"] = @"release";
    FKHelperTrustManifest *release = [FKHelperTrustManifest manifestFromDictionary:releaseDict];
    NSString *digest = [@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0];
    FKHelperReleaseVerificationResult *noAnchor = [verifier verifyManifest:release signature:[NSData dataWithBytes:"x" length:1] expectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-0118" architecture:@"arm64e" actualSHA256:digest];
    if (noAnchor.status != FKHelperReleaseVerificationUnknown || ![noAnchor.reasonCode isEqualToString:@"trusted_anchor_unavailable"]) [f addObject:@"REL1703 无生产锚点必须 Unknown"];
    FKHelperReleaseVerificationResult *idMismatch = [verifier verifyManifest:release signature:nil expectedHelperID:@"other" expectedBuildID:@"FKH-0118" architecture:@"arm64e" actualSHA256:digest];
    if (idMismatch.status != FKHelperReleaseVerificationInvalid) [f addObject:@"REL1704 Helper ID 错配必须 Invalid"];
    FKHelperReleaseVerificationResult *buildMismatch = [verifier verifyManifest:release signature:nil expectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-9999" architecture:@"arm64e" actualSHA256:digest];
    if (buildMismatch.status != FKHelperReleaseVerificationInvalid) [f addObject:@"REL1705 Build ID 错配必须 Invalid"];
    FKHelperReleaseVerificationResult *digestMismatch = [verifier verifyManifest:release signature:nil expectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-0118" architecture:@"arm64e" actualSHA256:[@"b" stringByPaddingToLength:64 withString:@"b" startingAtIndex:0]];
    if (digestMismatch.status != FKHelperReleaseVerificationInvalid) [f addObject:@"REL1706 摘要不一致必须 Invalid"];
    FKHelperReleaseVerificationResult *archMissing = [verifier verifyManifest:release signature:nil expectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-0118" architecture:@"arm64" actualSHA256:digest];
    if (archMissing.status != FKHelperReleaseVerificationUnknown) [f addObject:@"REL1707 缺失架构产物必须 Unknown"];
    if ([[noAnchor JSONDictionary][@"allowsTrustedRelease"] boolValue]) [f addObject:@"REL1708 未验证结果不得放行"];
    return f.copy;
}
@end
