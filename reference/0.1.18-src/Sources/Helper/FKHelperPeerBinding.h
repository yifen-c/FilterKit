#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

/// Peer 绑定快照；credentialDigest 是外部 Transport 对系统 Peer 凭据的摘要，不自行伪造。
@interface FKHelperPeerBinding : NSObject
@property (nonatomic, copy, readonly) NSString *sessionID;
@property (nonatomic, copy, readonly) NSString *clientID;
@property (nonatomic, copy, readonly) NSString *helperID;
@property (nonatomic, copy, readonly) NSString *helperBuildID;
@property (nonatomic, copy, readonly) NSString *credentialDigest;
@property (nonatomic, copy, readonly) NSString *transcriptDigest;
- (nullable instancetype)initWithSessionID:(NSString *)sessionID
                                  clientID:(NSString *)clientID
                                  helperID:(NSString *)helperID
                              helperBuildID:(NSString *)helperBuildID
                           credentialDigest:(NSString *)credentialDigest
                           transcriptDigest:(NSString *)transcriptDigest NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)matchesExpectedHelperID:(NSString *)expectedHelperID
                  expectedBuildID:(NSString *)expectedBuildID
                expectedCredential:(NSString *)expectedCredentialDigest;
- (NSDictionary *)JSONDictionary;
@end
NS_ASSUME_NONNULL_END
