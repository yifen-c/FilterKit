#import "FKHelperManifestTests.h"
#import "FKHelperTrustManifest.h"
#import "FKHelperManifestVerifier.h"

@implementation FKHelperManifestTests

+ (NSUInteger)checkCount { return 12; }

+ (NSDictionary *)baseManifestDictionary {
    return @{
        @"schemaVersion": @1,
        @"product": @"FilterKit",
        @"component": @"FilterKitHelper",
        @"helperID": @"com.filterkit.helper",
        @"release": @{@"version": @"0.1.18", @"buildID": @"FKH-0118", @"channel": @"development"},
        @"protocol": @{@"major": @1, @"minor": @0},
        @"artifacts": @[],
        @"releaseStatus": @"development"
    };
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSString *expectedID = @"com.filterkit.helper";

    // HMF801：清单读取成功。
    FKHelperTrustManifest *manifest = [FKHelperTrustManifest manifestFromDictionary:[self baseManifestDictionary]];
    if (manifest == nil) {
        [failures addObject:@"HMF801 清单字典解析返回 nil"];
        return failures.copy;
    }

    // HMF802：JSON 合法且往返保留。
    NSDictionary *json = manifest.JSONDictionary;
    FKHelperTrustManifest *roundTrip = [FKHelperTrustManifest manifestFromDictionary:json];
    if (roundTrip == nil || ![roundTrip.buildID isEqualToString:manifest.buildID]) {
        [failures addObject:@"HMF802 清单 JSON 往返失败"];
    }

    // HMF803：Schema Version 受支持。
    if (manifest.schemaVersion != 1) {
        [failures addObject:@"HMF803 清单 schemaVersion 非受支持版本"];
    }

    // HMF804：Helper ID 匹配。
    if (![manifest.helperID isEqualToString:expectedID]) {
        [failures addObject:@"HMF804 清单 Helper ID 与预期不匹配"];
    }

    // HMF805：Build ID 匹配。
    if (![manifest.buildID isEqualToString:@"FKH-0118"]) {
        [failures addObject:@"HMF805 清单 Build ID 与预期不匹配"];
    }

    // HMF806：协议可解析。
    if (manifest.protocolMajor != 1 || manifest.protocolMinor != 0) {
        [failures addObject:@"HMF806 清单协议版本不可解析"];
    }

    // HMF807：空摘要清单不允许作为可信依据。
    if ([manifest hasTrustedArtifacts]) {
        [failures addObject:@"HMF807 空摘要清单不应视为登记了可信产物"];
    }
    FKHelperManifestVerificationResult *unsignedResult =
        [FKHelperManifestVerifier verifyManifest:manifest signature:nil expectedHelperID:expectedID];
    if (unsignedResult.allowsTrustedRelease) {
        [failures addObject:@"HMF807 无可信摘要的清单不得放行"];
    }

    // HMF808：错误（非法格式）摘要被拒绝。
    NSMutableDictionary *badDigest = [[self baseManifestDictionary] mutableCopy];
    badDigest[@"artifacts"] = @[@{@"architecture": @"arm64e", @"sha256": @"not-a-valid-digest"}];
    FKHelperTrustManifest *badDigestManifest = [FKHelperTrustManifest manifestFromDictionary:badDigest];
    FKHelperManifestVerificationResult *badDigestResult =
        [FKHelperManifestVerifier verifyManifest:badDigestManifest signature:nil expectedHelperID:expectedID];
    if (badDigestResult.status != FKHelperManifestStatusInvalid) {
        [failures addObject:@"HMF808 非法摘要清单应判定为 Invalid"];
    }

    // HMF809：无签名清单保持 Unknown。
    if (unsignedResult.status != FKHelperManifestStatusUnknown) {
        [failures addObject:@"HMF809 无签名清单应保持 Unknown"];
    }

    // HMF810：签名损坏结论为 Invalid，不得放行。
    FKHelperManifestVerificationResult *corrupt =
        [FKHelperManifestVerifier invalidResultWithReason:@"signature_invalid"
                                              description:@"清单签名与内容不一致"
                                                    error:FKHelperManifestErrorSignatureInvalid];
    if (corrupt.status != FKHelperManifestStatusInvalid || corrupt.allowsTrustedRelease) {
        [failures addObject:@"HMF810 错误签名应判定 Invalid 且不放行"];
    }

    // HMF811：未知 Key ID 保持 Unknown。
    NSMutableDictionary *unknownKey = [[self baseManifestDictionary] mutableCopy];
    unknownKey[@"manifestKeyID"] = @"";
    FKHelperTrustManifest *unknownKeyManifest = [FKHelperTrustManifest manifestFromDictionary:unknownKey];
    NSData *fakeSignature = [@"placeholder-signature" dataUsingEncoding:NSUTF8StringEncoding];
    FKHelperManifestVerificationResult *unknownKeyResult =
        [FKHelperManifestVerifier verifyManifest:unknownKeyManifest signature:fakeSignature expectedHelperID:expectedID];
    if (unknownKeyResult.status != FKHelperManifestStatusUnknown ||
        ![unknownKeyResult.reasonCode isEqualToString:@"unknown_key_id"]) {
        [failures addObject:@"HMF811 未知 Key ID 应保持 Unknown"];
    }

    // HMF812：开发版本不得冒充正式发布。
    if (![manifest isDevelopmentRelease]) {
        [failures addObject:@"HMF812 开发通道清单应被识别为开发版"];
    }
    FKHelperManifestVerificationResult *devResult =
        [FKHelperManifestVerifier verifyManifest:manifest signature:fakeSignature expectedHelperID:expectedID];
    if (devResult.status == FKHelperManifestStatusVerified) {
        [failures addObject:@"HMF812 开发版本不得判为 Verified 正式发布"];
    }

    return failures.copy;
}

@end
