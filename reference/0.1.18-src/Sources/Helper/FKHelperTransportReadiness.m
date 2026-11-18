#import "FKHelperTransportReadiness.h"
#import <math.h>

@interface FKHelperTransportEvidence ()
@property (nonatomic, assign, readwrite) FKHelperTransportEvidenceSource source;
@property (nonatomic, copy, readwrite) NSString *transportKind;
@property (nonatomic, copy, readwrite) NSString *endpointIdentifier;
@property (nonatomic, assign, readwrite) BOOL endpointObserved;
@property (nonatomic, assign, readwrite) BOOL connected;
@property (nonatomic, assign, readwrite) BOOL lifecycleVerified;
@property (nonatomic, strong, readwrite) NSDate *observedAt;
- (instancetype)initPrivateWithSource:(FKHelperTransportEvidenceSource)source kind:(NSString *)kind endpoint:(NSString *)endpoint connected:(BOOL)connected date:(NSDate *)date;
@end
@implementation FKHelperTransportEvidence
- (instancetype)initPrivateWithSource:(FKHelperTransportEvidenceSource)source kind:(NSString *)kind endpoint:(NSString *)endpoint connected:(BOOL)connected date:(NSDate *)date {
    self = [super init]; if (self) { _source = source; _transportKind = [kind copy] ?: @"unsupported"; _endpointIdentifier = [endpoint copy] ?: @""; _endpointObserved = endpoint.length > 0; _connected = connected; _lifecycleVerified = NO; _observedAt = date ?: [NSDate dateWithTimeIntervalSince1970:0]; } return self;
}
+ (instancetype)unsupportedEvidence { return [[self alloc] initPrivateWithSource:FKHelperTransportEvidenceSourceUnsupported kind:@"unsupported" endpoint:@"" connected:NO date:[NSDate dateWithTimeIntervalSince1970:0]]; }
+ (instancetype)mockEvidenceWithKind:(NSString *)kind endpoint:(NSString *)endpoint connected:(BOOL)connected date:(NSDate *)date { return [[self alloc] initPrivateWithSource:FKHelperTransportEvidenceSourceMock kind:kind endpoint:endpoint connected:connected date:date]; }
- (BOOL)isProductionEvidence { return NO; }
- (NSDictionary *)JSONDictionary {
    return @{ @"source": self.source == FKHelperTransportEvidenceSourceMock ? @"mock" : @"unsupported",
              @"transportKind": self.transportKind ?: @"unsupported", @"endpointIdentifier": self.endpointIdentifier ?: @"",
              @"endpointObserved": @(self.endpointObserved), @"connected": @(self.connected),
              @"lifecycleVerified": @(self.lifecycleVerified), @"productionEvidence": @(self.isProductionEvidence),
              @"observedAt": @([self.observedAt timeIntervalSince1970]) };
}
@end

@interface FKHelperTransportReadiness ()
@property (nonatomic, assign, readwrite) BOOL ready;
@property (nonatomic, assign, readwrite) BOOL realTransportVerified;
@end
@implementation FKHelperTransportReadiness
- (NSDictionary *)JSONDictionary { return @{ @"status": self.status ?: @"unavailable", @"reasonCode": self.reasonCode ?: @"",
    @"missingEvidence": self.missingEvidence ?: @[], @"ready": @(self.ready), @"realTransportVerified": @(self.realTransportVerified) }; }
@end

@implementation FKHelperTransportReadinessEvaluator
- (FKHelperTransportReadiness *)evaluateTransport:(FKHelperTransportEvidence *)transport peerCredential:(FKHelperPeerCredentialVerificationResult *)peerCredential releaseTrust:(FKHelperReleaseVerificationResult *)releaseTrust atDate:(NSDate *)date {
    NSMutableArray *missing = [NSMutableArray array];
    if (!transport) [missing addObject:@"transport_evidence"];
    else {
        if (!transport.isProductionEvidence) [missing addObject:@"production_transport_attestation"];
        if (!transport.endpointObserved) [missing addObject:@"verified_endpoint"];
        if (!transport.connected) [missing addObject:@"active_connection"];
        if (!transport.lifecycleVerified) [missing addObject:@"transport_lifecycle"];
        if (fabs([date timeIntervalSinceDate:transport.observedAt]) > 60.0 || [transport.observedAt timeIntervalSinceDate:date] > 5.0) [missing addObject:@"fresh_transport_evidence"];
    }
    if (!peerCredential.verified) [missing addObject:@"verified_system_peer_credential"];
    if (!releaseTrust.allowsTrustedRelease) [missing addObject:@"verified_helper_release"];
    FKHelperTransportReadiness *result = [FKHelperTransportReadiness new];
    result.missingEvidence = missing.copy; result.ready = missing.count == 0;
    result.realTransportVerified = result.ready;
    result.status = result.ready ? @"ready" : @"unavailable";
    result.reasonCode = result.ready ? @"all_required_evidence_verified" : @"required_evidence_missing";
    return result;
}
@end
