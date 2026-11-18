#import <Foundation/Foundation.h>
#import <sys/types.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FKHelperPeerCredentialSource) {
    FKHelperPeerCredentialSourceUnsupported = 0,
    FKHelperPeerCredentialSourceMock,
    FKHelperPeerCredentialSourceSelfReported
};

typedef NS_ENUM(NSInteger, FKHelperPeerCredentialStatus) {
    FKHelperPeerCredentialStatusUnavailable = 0,
    FKHelperPeerCredentialStatusUnverified,
    FKHelperPeerCredentialStatusRejected,
    FKHelperPeerCredentialStatusVerified
};

/// 0.1.18 只提供 Mock / Self-reported / Unsupported 证据构造；不提供偽造 System Credential 的公开工厂。
@interface FKHelperPeerCredentialEvidence : NSObject
@property (nonatomic, assign, readonly) FKHelperPeerCredentialSource source;
@property (nonatomic, assign, readonly) pid_t processID;
@property (nonatomic, assign, readonly) uid_t effectiveUserID;
@property (nonatomic, copy, readonly) NSString *credentialDigest;
@property (nonatomic, copy, readonly) NSString *collectorIdentifier;
@property (nonatomic, strong, readonly, nullable) NSDate *collectedAt;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)unsupportedEvidence;
+ (instancetype)mockEvidenceWithProcessID:(pid_t)processID digest:(NSString *)digest date:(NSDate *)date;
+ (instancetype)selfReportedEvidenceWithProcessID:(pid_t)processID digest:(NSString *)digest date:(NSDate *)date;
- (NSDictionary *)JSONDictionary;
@end

@interface FKHelperPeerCredentialVerificationResult : NSObject
@property (nonatomic, assign) FKHelperPeerCredentialStatus status;
@property (nonatomic, copy) NSString *reasonCode;
@property (nonatomic, assign, readonly) BOOL verified;
- (NSDictionary *)JSONDictionary;
@end

@interface FKHelperPeerCredentialVerifier : NSObject
- (FKHelperPeerCredentialVerificationResult *)verifyEvidence:(nullable FKHelperPeerCredentialEvidence *)evidence atDate:(nullable NSDate *)date;
@end

NS_ASSUME_NONNULL_END
