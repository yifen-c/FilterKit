#import <Foundation/Foundation.h>
#import "FKHelperTrustAnchor.h"
#import "FKHelperTrustManifest.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FKHelperReleaseVerificationStatus) {
    FKHelperReleaseVerificationUnknown = 0,
    FKHelperReleaseVerificationVerified,
    FKHelperReleaseVerificationInvalid,
    FKHelperReleaseVerificationUnavailable
};

@protocol FKHelperReleaseSignatureVerifying <NSObject>
- (BOOL)verifyData:(NSData *)data signature:(NSData *)signature
        publicKey:(NSData *)publicKey algorithm:(NSString *)algorithm
             error:(NSError * _Nullable * _Nullable)error;
@end

@interface FKHelperReleaseVerificationResult : NSObject
@property (nonatomic, assign) FKHelperReleaseVerificationStatus status;
@property (nonatomic, copy) NSString *reasonCode;
@property (nonatomic, copy) NSString *keyID;
@property (nonatomic, copy) NSString *verifiedBuildID;
@property (nonatomic, assign, readonly) BOOL allowsTrustedRelease;
- (NSDictionary *)JSONDictionary;
@end

/// 发布验证器。未配置生产锚点或真实签名验证实现时绝不产生 Verified。
@interface FKHelperReleaseVerifier : NSObject
@property (nonatomic, strong, readonly) FKHelperTrustAnchorStore *anchorStore;
@property (nonatomic, strong, readonly, nullable) id<FKHelperReleaseSignatureVerifying> signatureVerifier;
- (instancetype)initWithAnchorStore:(FKHelperTrustAnchorStore *)anchorStore
                   signatureVerifier:(nullable id<FKHelperReleaseSignatureVerifying>)signatureVerifier;
- (FKHelperReleaseVerificationResult *)verifyManifest:(nullable FKHelperTrustManifest *)manifest
                                          signature:(nullable NSData *)signature
                                    expectedHelperID:(NSString *)expectedHelperID
                                   expectedBuildID:(NSString *)expectedBuildID
                                       architecture:(NSString *)architecture
                                    actualSHA256:(nullable NSString *)actualSHA256;
@end

NS_ASSUME_NONNULL_END
