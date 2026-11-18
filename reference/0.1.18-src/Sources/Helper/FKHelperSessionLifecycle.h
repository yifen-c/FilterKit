#import <Foundation/Foundation.h>
@class FKHelperKeyLifecycle;
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FKHelperManagedSessionState) {
    FKHelperManagedSessionStateEmpty = 0,
    FKHelperManagedSessionStateActive,
    FKHelperManagedSessionStateExpired,
    FKHelperManagedSessionStateInvalidated
};

/// 会话生命周期闸门；只有完整双向确认和 Peer 绑定后才可建立。
@interface FKHelperSessionLifecycle : NSObject
@property (nonatomic, readonly) FKHelperManagedSessionState state;
@property (nonatomic, copy, readonly) NSString *sessionID;
- (instancetype)initWithMaximumLifetime:(NSTimeInterval)maximumLifetime idleTimeout:(NSTimeInterval)idleTimeout;
- (instancetype)initWithMaximumLifetime:(NSTimeInterval)maximumLifetime
                            idleTimeout:(NSTimeInterval)idleTimeout
                           keyLifecycle:(nullable FKHelperKeyLifecycle *)keyLifecycle;
- (BOOL)beginSessionWithID:(NSString *)sessionID peerBindingVerified:(BOOL)peerVerified
 clientConfirmationVerified:(BOOL)clientConfirmed helperConfirmationVerified:(BOOL)helperConfirmed
                      date:(NSDate *)date;
- (BOOL)touchAtDate:(NSDate *)date;
- (BOOL)isActiveAtDate:(NSDate *)date;
- (void)invalidateWithReason:(NSString *)reason;
@property (nonatomic, copy, readonly) NSString *terminalReason;
@end
NS_ASSUME_NONNULL_END
