#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FKHelperHandshakePhase) {
    FKHelperHandshakePhaseIdle = 0,
    FKHelperHandshakePhasePeerVerified,
    FKHelperHandshakePhaseProtocolNegotiated,
    FKHelperHandshakePhaseTranscriptVerified,
    FKHelperHandshakePhaseKeyDerived,
    FKHelperHandshakePhaseClientConfirmed,
    FKHelperHandshakePhaseEstablished,
    FKHelperHandshakePhaseFailed,
    FKHelperHandshakePhaseExpired
};

/// 严格单向握手状态机；每一步必须附带对应的布尔证据。
@interface FKHelperHandshakeStateMachine : NSObject
@property (nonatomic, readonly) FKHelperHandshakePhase phase;
@property (nonatomic, copy, readonly) NSString *failureReason;
- (BOOL)advanceToPhase:(FKHelperHandshakePhase)phase evidence:(NSDictionary *)evidence error:(NSError **)error;
- (void)failWithReason:(NSString *)reason;
- (void)expire;
- (void)reset;
@end
NS_ASSUME_NONNULL_END
