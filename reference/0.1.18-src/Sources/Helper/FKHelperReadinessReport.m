#import "FKHelperReadinessReport.h"

@interface FKHelperReadinessReport ()
@property (nonatomic, assign, readwrite) BOOL realIPCReady;
@property (nonatomic, assign, readwrite) BOOL readOnlyOperationsAllowed;
@property (nonatomic, assign, readwrite) BOOL writeOperationsAllowed;
@end
@implementation FKHelperReadinessReport
- (NSDictionary *)JSONDictionary {
    return @{ @"helperIdentityStatus": self.helperIdentityStatus ?: @"unknown", @"releaseTrustStatus": self.releaseTrustStatus ?: @"unknown",
              @"peerCredentialStatus": self.peerCredentialStatus ?: @"unavailable", @"transportStatus": self.transportStatus ?: @"unavailable",
              @"blockingReasons": self.blockingReasons ?: @[], @"realIPCReady": @(self.realIPCReady),
              @"readOnlyOperationsAllowed": @(self.readOnlyOperationsAllowed), @"writeOperationsAllowed": @(self.writeOperationsAllowed) };
}
@end
@implementation FKHelperReadinessEvaluator
- (FKHelperReadinessReport *)reportForHelperID:(NSString *)helperID releaseTrust:(FKHelperReleaseVerificationResult *)releaseTrust peerCredential:(FKHelperPeerCredentialVerificationResult *)peerCredential transport:(FKHelperTransportReadiness *)transport {
    NSMutableArray *reasons = [NSMutableArray array];
    BOOL identityPresent = [helperID isKindOfClass:NSString.class] && helperID.length > 0;
    if (!identityPresent) [reasons addObject:@"helper_identity_missing"];
    if (!releaseTrust.allowsTrustedRelease) [reasons addObject:releaseTrust.reasonCode.length ? releaseTrust.reasonCode : @"release_trust_unavailable"];
    if (!peerCredential.verified) [reasons addObject:peerCredential.reasonCode.length ? peerCredential.reasonCode : @"peer_credential_unavailable"];
    if (!transport.ready) [reasons addObject:transport.reasonCode.length ? transport.reasonCode : @"transport_unavailable"];
    FKHelperReadinessReport *report = [FKHelperReadinessReport new];
    report.helperIdentityStatus = identityPresent ? @"declared_unverified" : @"missing";
    report.releaseTrustStatus = releaseTrust ? [releaseTrust JSONDictionary][@"status"] : @"unknown";
    report.peerCredentialStatus = peerCredential ? [peerCredential JSONDictionary][@"status"] : @"unavailable";
    report.transportStatus = transport.status ?: @"unavailable";
    report.blockingReasons = reasons.copy;
    // 0.1.18 不存在真实系统采集器/Transport，因此操作能力始终关闭。
    report.realIPCReady = NO;
    report.readOnlyOperationsAllowed = NO;
    report.writeOperationsAllowed = NO;
    return report;
}
@end
