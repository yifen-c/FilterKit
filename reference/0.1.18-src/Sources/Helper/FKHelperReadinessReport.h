#import <Foundation/Foundation.h>
#import "FKHelperTransportReadiness.h"

NS_ASSUME_NONNULL_BEGIN

/// 汇总 Helper 身份、Peer、Transport 与操作安全状态；不自行创建或提升证据。
@interface FKHelperReadinessReport : NSObject
@property (nonatomic, copy) NSString *helperIdentityStatus;
@property (nonatomic, copy) NSString *releaseTrustStatus;
@property (nonatomic, copy) NSString *peerCredentialStatus;
@property (nonatomic, copy) NSString *transportStatus;
@property (nonatomic, copy) NSArray<NSString *> *blockingReasons;
@property (nonatomic, assign, readonly) BOOL realIPCReady;
@property (nonatomic, assign, readonly) BOOL readOnlyOperationsAllowed;
@property (nonatomic, assign, readonly) BOOL writeOperationsAllowed;
- (NSDictionary *)JSONDictionary;
@end

@interface FKHelperReadinessEvaluator : NSObject
- (FKHelperReadinessReport *)reportForHelperID:(NSString *)helperID
                                  releaseTrust:(nullable FKHelperReleaseVerificationResult *)releaseTrust
                                peerCredential:(nullable FKHelperPeerCredentialVerificationResult *)peerCredential
                                     transport:(nullable FKHelperTransportReadiness *)transport;
@end

NS_ASSUME_NONNULL_END
