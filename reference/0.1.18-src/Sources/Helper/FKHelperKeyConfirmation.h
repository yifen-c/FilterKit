#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FKHelperConfirmationRole) {
    FKHelperConfirmationRoleClient = 1,
    FKHelperConfirmationRoleHelper = 2
};

/// 双向密钥确认；证明双方持有同一会话密钥，不替代 Peer 身份验证。
@interface FKHelperKeyConfirmation : NSObject
- (nullable NSString *)proofForRole:(FKHelperConfirmationRole)role
                           sessionID:(NSString *)sessionID
                     transcriptDigest:(NSString *)transcriptDigest
                                  key:(NSData *)key;
- (BOOL)verifyProof:(NSString *)proof
               role:(FKHelperConfirmationRole)role
          sessionID:(NSString *)sessionID
   transcriptDigest:(NSString *)transcriptDigest
                key:(NSData *)key;
@end
NS_ASSUME_NONNULL_END
