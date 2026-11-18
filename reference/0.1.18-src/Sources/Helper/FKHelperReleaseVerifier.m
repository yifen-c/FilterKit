#import "FKHelperReleaseVerifier.h"

@implementation FKHelperReleaseVerificationResult
- (BOOL)allowsTrustedRelease { return self.status == FKHelperReleaseVerificationVerified; }
- (NSDictionary *)JSONDictionary {
    return @{ @"status": self.status == FKHelperReleaseVerificationVerified ? @"verified" :
              (self.status == FKHelperReleaseVerificationInvalid ? @"invalid" :
               (self.status == FKHelperReleaseVerificationUnavailable ? @"unavailable" : @"unknown")),
              @"reasonCode": self.reasonCode ?: @"", @"keyID": self.keyID ?: @"",
              @"verifiedBuildID": self.verifiedBuildID ?: @"", @"allowsTrustedRelease": @(self.allowsTrustedRelease) };
}
@end

@implementation FKHelperReleaseVerifier
- (instancetype)initWithAnchorStore:(FKHelperTrustAnchorStore *)anchorStore signatureVerifier:(id<FKHelperReleaseSignatureVerifying>)signatureVerifier {
    self = [super init];
    if (self) { _anchorStore = anchorStore ?: [FKHelperTrustAnchorStore new]; _signatureVerifier = signatureVerifier; }
    return self;
}
- (FKHelperReleaseVerificationResult *)result:(FKHelperReleaseVerificationStatus)status reason:(NSString *)reason keyID:(NSString *)keyID build:(NSString *)build {
    FKHelperReleaseVerificationResult *r = [FKHelperReleaseVerificationResult new];
    r.status = status; r.reasonCode = reason ?: @"unknown"; r.keyID = keyID ?: @""; r.verifiedBuildID = build ?: @"";
    return r;
}
- (FKHelperReleaseVerificationResult *)verifyManifest:(FKHelperTrustManifest *)manifest signature:(NSData *)signature
                                    expectedHelperID:(NSString *)expectedHelperID expectedBuildID:(NSString *)expectedBuildID
                                       architecture:(NSString *)architecture actualSHA256:(NSString *)actualSHA256 {
    if (!manifest) return [self result:FKHelperReleaseVerificationUnavailable reason:@"manifest_unavailable" keyID:@"" build:@""];
    if (![manifest isStructurallyValid] || expectedHelperID.length == 0 || expectedBuildID.length == 0 || architecture.length == 0)
        return [self result:FKHelperReleaseVerificationInvalid reason:@"manifest_or_expectation_invalid" keyID:manifest.manifestKeyID build:manifest.buildID];
    if (![manifest.helperID isEqualToString:expectedHelperID] || ![manifest.buildID isEqualToString:expectedBuildID])
        return [self result:FKHelperReleaseVerificationInvalid reason:@"helper_identity_mismatch" keyID:manifest.manifestKeyID build:manifest.buildID];
    if (manifest.isDevelopmentRelease)
        return [self result:FKHelperReleaseVerificationUnknown reason:@"development_channel" keyID:manifest.manifestKeyID build:manifest.buildID];
    FKHelperArtifact *artifact = [manifest artifactForArchitecture:architecture];
    if (!artifact || ![FKHelperTrustManifest isValidSHA256Hex:artifact.sha256] || ![FKHelperTrustManifest isValidSHA256Hex:actualSHA256])
        return [self result:FKHelperReleaseVerificationUnknown reason:@"artifact_digest_unavailable" keyID:manifest.manifestKeyID build:manifest.buildID];
    if ([artifact.sha256 caseInsensitiveCompare:actualSHA256] != NSOrderedSame)
        return [self result:FKHelperReleaseVerificationInvalid reason:@"artifact_digest_mismatch" keyID:manifest.manifestKeyID build:manifest.buildID];
    FKHelperTrustAnchor *anchor = [self.anchorStore productionAnchorForKeyID:manifest.manifestKeyID];
    if (!anchor) return [self result:FKHelperReleaseVerificationUnknown reason:@"trusted_anchor_unavailable" keyID:manifest.manifestKeyID build:manifest.buildID];
    if (signature.length == 0) return [self result:FKHelperReleaseVerificationUnknown reason:@"manifest_signature_missing" keyID:manifest.manifestKeyID build:manifest.buildID];
    if (!self.signatureVerifier) return [self result:FKHelperReleaseVerificationUnavailable reason:@"signature_verifier_unavailable" keyID:manifest.manifestKeyID build:manifest.buildID];
    NSError *error = nil;
    NSData *canonical = [NSJSONSerialization dataWithJSONObject:manifest.JSONDictionary options:NSJSONWritingSortedKeys error:&error];
    if (!canonical) return [self result:FKHelperReleaseVerificationInvalid reason:@"manifest_canonicalization_failed" keyID:manifest.manifestKeyID build:manifest.buildID];
    BOOL valid = [self.signatureVerifier verifyData:canonical signature:signature publicKey:anchor.publicKeyData algorithm:anchor.algorithm error:&error];
    if (!valid) return [self result:FKHelperReleaseVerificationInvalid reason:@"manifest_signature_invalid" keyID:manifest.manifestKeyID build:manifest.buildID];
    return [self result:FKHelperReleaseVerificationVerified reason:@"verified" keyID:anchor.keyID build:manifest.buildID];
}
@end
