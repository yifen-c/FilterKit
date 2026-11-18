#import "FKHelperPeerCredentialEvidence.h"

@interface FKHelperPeerCredentialEvidence ()
@property (nonatomic, assign, readwrite) FKHelperPeerCredentialSource source;
@property (nonatomic, assign, readwrite) pid_t processID;
@property (nonatomic, assign, readwrite) uid_t effectiveUserID;
@property (nonatomic, copy, readwrite) NSString *credentialDigest;
@property (nonatomic, copy, readwrite) NSString *collectorIdentifier;
@property (nonatomic, strong, readwrite, nullable) NSDate *collectedAt;
- (instancetype)initPrivateWithSource:(FKHelperPeerCredentialSource)source pid:(pid_t)pid digest:(NSString *)digest date:(NSDate *)date;
@end
@implementation FKHelperPeerCredentialEvidence
- (instancetype)initPrivateWithSource:(FKHelperPeerCredentialSource)source pid:(pid_t)pid digest:(NSString *)digest date:(NSDate *)date {
    self = [super init]; if (self) { _source = source; _processID = pid; _credentialDigest = [digest isKindOfClass:NSString.class] ? [digest copy] : @""; _collectedAt = date; _collectorIdentifier = source == FKHelperPeerCredentialSourceMock ? @"mock" : (source == FKHelperPeerCredentialSourceSelfReported ? @"self_reported" : @"unsupported"); _effectiveUserID = (uid_t)-1; } return self;
}
+ (instancetype)unsupportedEvidence { return [[self alloc] initPrivateWithSource:FKHelperPeerCredentialSourceUnsupported pid:0 digest:@"" date:nil]; }
+ (instancetype)mockEvidenceWithProcessID:(pid_t)processID digest:(NSString *)digest date:(NSDate *)date { return [[self alloc] initPrivateWithSource:FKHelperPeerCredentialSourceMock pid:processID digest:digest date:date]; }
+ (instancetype)selfReportedEvidenceWithProcessID:(pid_t)processID digest:(NSString *)digest date:(NSDate *)date { return [[self alloc] initPrivateWithSource:FKHelperPeerCredentialSourceSelfReported pid:processID digest:digest date:date]; }
- (NSDictionary *)JSONDictionary {
    NSString *source = self.source == FKHelperPeerCredentialSourceMock ? @"mock" : (self.source == FKHelperPeerCredentialSourceSelfReported ? @"self_reported" : @"unsupported");
    return @{ @"source": source, @"pid": @(self.processID), @"uid": @(self.effectiveUserID),
              @"credentialDigest": self.credentialDigest ?: @"", @"collectorIdentifier": self.collectorIdentifier ?: @"",
              @"collectedAt": self.collectedAt ? @([self.collectedAt timeIntervalSince1970]) : [NSNull null] };
}
@end

@implementation FKHelperPeerCredentialVerificationResult
- (BOOL)verified { return self.status == FKHelperPeerCredentialStatusVerified; }
- (NSDictionary *)JSONDictionary {
    NSString *status = self.status == FKHelperPeerCredentialStatusVerified ? @"verified" :
        (self.status == FKHelperPeerCredentialStatusRejected ? @"rejected" :
         (self.status == FKHelperPeerCredentialStatusUnverified ? @"unverified" : @"unavailable"));
    return @{ @"status": status, @"reasonCode": self.reasonCode ?: @"", @"verified": @(self.verified) };
}
@end

@implementation FKHelperPeerCredentialVerifier
- (FKHelperPeerCredentialVerificationResult *)verifyEvidence:(FKHelperPeerCredentialEvidence *)evidence atDate:(NSDate *)date {
    FKHelperPeerCredentialVerificationResult *result = [FKHelperPeerCredentialVerificationResult new];
    result.status = FKHelperPeerCredentialStatusUnavailable; result.reasonCode = @"system_peer_credential_collector_not_implemented";
    if (![date isKindOfClass:NSDate.class]) { result.status = FKHelperPeerCredentialStatusRejected; result.reasonCode = @"invalid_evaluation_date"; return result; }
    if (!evidence || evidence.source == FKHelperPeerCredentialSourceUnsupported) return result;
    result.status = FKHelperPeerCredentialStatusRejected;
    result.reasonCode = evidence.source == FKHelperPeerCredentialSourceMock ? @"mock_credential_not_trusted" : @"self_reported_credential_not_trusted";
    return result;
}
@end
