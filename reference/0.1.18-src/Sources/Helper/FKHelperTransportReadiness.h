#import <Foundation/Foundation.h>
#import "FKHelperPeerCredentialEvidence.h"
#import "FKHelperReleaseVerifier.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FKHelperTransportEvidenceSource) {
    FKHelperTransportEvidenceSourceUnsupported = 0,
    FKHelperTransportEvidenceSourceMock
};

/// Transport 证据模型。当前版本只能构造 Mock 或 Unsupported，不代表真实系统端点。
@interface FKHelperTransportEvidence : NSObject
@property (nonatomic, assign, readonly) FKHelperTransportEvidenceSource source;
@property (nonatomic, copy, readonly) NSString *transportKind;
@property (nonatomic, copy, readonly) NSString *endpointIdentifier;
@property (nonatomic, assign, readonly) BOOL endpointObserved;
@property (nonatomic, assign, readonly) BOOL connected;
@property (nonatomic, assign, readonly) BOOL lifecycleVerified;
@property (nonatomic, strong, readonly) NSDate *observedAt;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)unsupportedEvidence;
+ (instancetype)mockEvidenceWithKind:(NSString *)kind endpoint:(NSString *)endpoint connected:(BOOL)connected date:(NSDate *)date;
- (BOOL)isProductionEvidence;
- (NSDictionary *)JSONDictionary;
@end

@interface FKHelperTransportReadiness : NSObject
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *reasonCode;
@property (nonatomic, copy) NSArray<NSString *> *missingEvidence;
@property (nonatomic, assign, readonly) BOOL ready;
@property (nonatomic, assign, readonly) BOOL realTransportVerified;
- (NSDictionary *)JSONDictionary;
@end

@interface FKHelperTransportReadinessEvaluator : NSObject
- (FKHelperTransportReadiness *)evaluateTransport:(nullable FKHelperTransportEvidence *)transport
                                   peerCredential:(nullable FKHelperPeerCredentialVerificationResult *)peerCredential
                                      releaseTrust:(nullable FKHelperReleaseVerificationResult *)releaseTrust
                                            atDate:(NSDate *)date;
@end

NS_ASSUME_NONNULL_END
