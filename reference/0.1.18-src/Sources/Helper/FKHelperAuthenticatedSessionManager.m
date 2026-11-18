#import "FKHelperAuthenticatedSessionManager.h"
#import "FKHelperPeerBinding.h"
#import "FKHelperKeyLifecycle.h"
#import "FKHelperHandshakeStateMachine.h"
#import "FKHelperSessionLifecycle.h"
#import "FKHelperKeyConfirmation.h"
#import "FKHelperIPCAuditEvent.h"
#import "FKAuditManager.h"
#import <math.h>

static NSError *FKAuthSessionError(NSString *code, NSString *message) {
    return [NSError errorWithDomain:@"com.filterkit.authenticated-session" code:1
                           userInfo:@{@"reasonCode": code ?: @"rejected",
                                      NSLocalizedDescriptionKey: message ?: @"认证会话建立失败"}];
}

@implementation FKHelperAuthenticatedSessionManager {
    NSRecursiveLock *_lock;
    FKHelperHandshakeStateMachine *_handshake;
    FKHelperSessionLifecycle *_lifecycle;
    FKHelperKeyLifecycle *_keyLifecycle;
    FKHelperKeyConfirmation *_confirmation;
    FKAuditManager *_auditManager;
    FKHelperAuthenticatedSessionState _state;
    NSString *_activeSessionID;
    NSString *_lastFailureReason;
    NSString *_source;
    NSString *_helperID;
    NSString *_buildID;
}

- (instancetype)initWithAuditManager:(FKAuditManager *)auditManager
                       keyLifecycle:(FKHelperKeyLifecycle *)keyLifecycle
                     maximumLifetime:(NSTimeInterval)maximumLifetime
                          idleTimeout:(NSTimeInterval)idleTimeout {
    self = [super init];
    if (self) {
        _lock = [NSRecursiveLock new];
        _auditManager = auditManager;
        _keyLifecycle = keyLifecycle ?: [FKHelperKeyLifecycle new];
        _lifecycle = [[FKHelperSessionLifecycle alloc] initWithMaximumLifetime:maximumLifetime
                                                                   idleTimeout:idleTimeout
                                                                  keyLifecycle:_keyLifecycle];
        _handshake = [FKHelperHandshakeStateMachine new];
        _confirmation = [FKHelperKeyConfirmation new];
        _state = FKHelperAuthenticatedSessionStateIdle;
        _activeSessionID = @"";
        _lastFailureReason = @"";
        _source = @"unsupported";
    }
    return self;
}

- (FKHelperAuthenticatedSessionState)state {
    [_lock lock]; FKHelperAuthenticatedSessionState value = _state; [_lock unlock]; return value;
}
- (NSString *)activeSessionID {
    [_lock lock]; NSString *value = [_activeSessionID copy]; [_lock unlock]; return value;
}
- (NSString *)lastFailureReason {
    [_lock lock]; NSString *value = [_lastFailureReason copy]; [_lock unlock]; return value;
}
- (BOOL)readOnlySessionEstablished {
    [_lock lock];
    BOOL value = _state == FKHelperAuthenticatedSessionStateEstablished &&
        _lifecycle.state == FKHelperManagedSessionStateActive &&
        _keyLifecycle.state == FKHelperKeyStateActive;
    [_lock unlock];
    return value;
}

- (void)appendAuditAction:(FKAuditHelperIPCAction)action result:(NSString *)result
               reasonCode:(NSString *)reasonCode sessionID:(NSString *)sessionID {
    if (!_auditManager) return;
    FKHelperIPCAuditEvent *event = [FKHelperIPCAuditEvent new];
    event.source = _source ?: @"unsupported";
    event.action = action;
    event.result = result ?: @"failed";
    event.helperID = _helperID;
    event.buildID = _buildID;
    event.sessionID = sessionID;
    event.reasonCode = reasonCode;
    [_auditManager appendHelperIPCAuditEvent:event];
}

- (BOOL)advance:(FKHelperHandshakePhase)phase evidenceKey:(NSString *)key {
    NSError *error = nil;
    BOOL ok = [_handshake advanceToPhase:phase evidence:@{key: @YES} error:&error];
    [self appendAuditAction:FKAuditHelperIPCHandshakeState
                     result:(ok ? @"success" : @"rejected")
                 reasonCode:(ok ? nil : @"state_transition_rejected")
                  sessionID:_activeSessionID];
    return ok;
}

- (FKHelperSessionKey *)createSessionKeyAtDate:(NSDate *)date {
    [_lock lock];
    if (_state == FKHelperAuthenticatedSessionStateEstablished) { [_lock unlock]; return nil; }
    FKHelperSessionKey *key = [_keyLifecycle createSessionKeyAtDate:date];
    [_lock unlock];
    return key;
}

- (BOOL)establishWithPeerBinding:(FKHelperPeerBinding *)binding
              expectedHelperID:(NSString *)expectedHelperID
                 expectedBuildID:(NSString *)expectedBuildID
        expectedCredentialDigest:(NSString *)expectedCredentialDigest
                             key:(FKHelperSessionKey *)sessionKey
                      clientProof:(NSString *)clientProof
                      helperProof:(NSString *)helperProof
                           source:(NSString *)source
                            date:(NSDate *)date
                           error:(NSError **)error {
    [_lock lock];
    if (_state == FKHelperAuthenticatedSessionStateEstablished ||
        _lifecycle.state == FKHelperManagedSessionStateActive) {
        if (error) *error = FKAuthSessionError(@"session_already_active", @"已有认证会话，拒绝覆盖");
        [_lock unlock]; return NO;
    }
    if (![date isKindOfClass:NSDate.class] || !isfinite(date.timeIntervalSince1970) ||
        ![binding isKindOfClass:FKHelperPeerBinding.class] ||
        ![sessionKey isKindOfClass:FKHelperSessionKey.class] ||
        sessionKey.state != FKHelperKeyStateActive ||
        ![@[@"mock", @"unsupported"] containsObject:source ?: @""]) {
        if (error) *error = FKAuthSessionError(@"invalid_input", @"会话输入或来源不合法");
        _state = FKHelperAuthenticatedSessionStateFailed;
        _lastFailureReason = @"invalid_input";
        _source = @"unsupported";
        [_keyLifecycle revokeActiveKey];
        [self appendAuditAction:FKAuditHelperIPCRejected result:@"rejected"
                     reasonCode:@"invalid_input" sessionID:nil];
        [_lock unlock]; return NO;
    }

    _state = FKHelperAuthenticatedSessionStateHandshaking;
    _source = [source copy];
    _helperID = binding.helperID;
    _buildID = binding.helperBuildID;
    _activeSessionID = binding.sessionID;
    [_handshake reset];

    BOOL peerOK = [binding matchesExpectedHelperID:expectedHelperID
                                    expectedBuildID:expectedBuildID
                                  expectedCredential:expectedCredentialDigest];
    FKHelperSessionKey *managedKey = [_keyLifecycle activeKeyAtDate:date];
    BOOL keyMatchesLifecycle = managedKey != nil &&
        [sessionKey.keyID isEqualToString:managedKey.keyID] &&
        [sessionKey.keyData isEqualToData:managedKey.keyData];
    // 外部密钥必须由本生命周期管理器创建，避免接受任意注入的密钥对象。
    if (!keyMatchesLifecycle) peerOK = NO;
    BOOL clientOK = peerOK && [_confirmation verifyProof:clientProof
                                                     role:FKHelperConfirmationRoleClient
                                                sessionID:binding.sessionID
                                          transcriptDigest:binding.transcriptDigest
                                                       key:sessionKey.keyData];
    BOOL helperOK = clientOK && [_confirmation verifyProof:helperProof
                                                       role:FKHelperConfirmationRoleHelper
                                                  sessionID:binding.sessionID
                                            transcriptDigest:binding.transcriptDigest
                                                         key:sessionKey.keyData];

    BOOL ok = peerOK && [self advance:FKHelperHandshakePhasePeerVerified evidenceKey:@"peer_verified"] &&
        [self advance:FKHelperHandshakePhaseProtocolNegotiated evidenceKey:@"protocol_negotiated"] &&
        [self advance:FKHelperHandshakePhaseTranscriptVerified evidenceKey:@"transcript_verified"] &&
        [self advance:FKHelperHandshakePhaseKeyDerived evidenceKey:@"key_derived"] &&
        clientOK && [self advance:FKHelperHandshakePhaseClientConfirmed evidenceKey:@"client_confirmation_verified"] &&
        helperOK && [self advance:FKHelperHandshakePhaseEstablished evidenceKey:@"helper_confirmation_verified"];

    if (ok) {
        ok = [_lifecycle beginSessionWithID:binding.sessionID peerBindingVerified:YES
              clientConfirmationVerified:YES helperConfirmationVerified:YES date:date];
    }
    if (!ok) {
        [_handshake failWithReason:@"authenticated_session_rejected"];
        [_keyLifecycle revokeActiveKey];
        _activeSessionID = @"";
        _state = FKHelperAuthenticatedSessionStateFailed;
        _lastFailureReason = peerOK ? @"key_confirmation_failed" : @"peer_binding_or_key_rejected";
        [self appendAuditAction:FKAuditHelperIPCKeyConfirmation result:@"rejected"
                     reasonCode:_lastFailureReason sessionID:binding.sessionID];
        if (error) *error = FKAuthSessionError(_lastFailureReason, @"Peer 绑定或双向密钥确认失败");
        [_lock unlock]; return NO;
    }

    _state = FKHelperAuthenticatedSessionStateEstablished;
    _lastFailureReason = @"";
    [self appendAuditAction:FKAuditHelperIPCPeerBinding result:@"success" reasonCode:nil sessionID:binding.sessionID];
    [self appendAuditAction:FKAuditHelperIPCKeyConfirmation result:@"success" reasonCode:nil sessionID:binding.sessionID];
    [self appendAuditAction:FKAuditHelperIPCHandshake result:@"success" reasonCode:nil sessionID:binding.sessionID];
    [_lock unlock];
    return YES;
}

- (BOOL)touchAtDate:(NSDate *)date {
    [_lock lock];
    BOOL ok = _state == FKHelperAuthenticatedSessionStateEstablished &&
        [_lifecycle touchAtDate:date];
    if (!ok && _state == FKHelperAuthenticatedSessionStateEstablished) {
        _state = (_lifecycle.state == FKHelperManagedSessionStateExpired) ?
            FKHelperAuthenticatedSessionStateExpired : FKHelperAuthenticatedSessionStateInvalidated;
        _lastFailureReason = _lifecycle.terminalReason;
        _activeSessionID = @"";
        [self appendAuditAction:FKAuditHelperIPCSessionExpired result:@"failed"
                     reasonCode:_lastFailureReason sessionID:nil];
    }
    [_lock unlock];
    return ok;
}

- (BOOL)expireIfNeededAtDate:(NSDate *)date {
    [_lock lock];
    BOOL activeBefore = _state == FKHelperAuthenticatedSessionStateEstablished;
    BOOL active = activeBefore && [_lifecycle isActiveAtDate:date];
    if (activeBefore && !active) {
        _state = (_lifecycle.state == FKHelperManagedSessionStateExpired) ?
            FKHelperAuthenticatedSessionStateExpired : FKHelperAuthenticatedSessionStateInvalidated;
        _lastFailureReason = _lifecycle.terminalReason;
        _activeSessionID = @"";
        [self appendAuditAction:FKAuditHelperIPCSessionExpired result:@"failed"
                     reasonCode:_lastFailureReason sessionID:nil];
    }
    [_lock unlock];
    return active;
}

- (void)invalidateWithReason:(NSString *)reason {
    [_lock lock];
    if (_state == FKHelperAuthenticatedSessionStateEstablished ||
        _state == FKHelperAuthenticatedSessionStateHandshaking) {
        NSString *sessionID = _activeSessionID;
        [_lifecycle invalidateWithReason:reason];
        [_keyLifecycle revokeActiveKey];
        [_handshake failWithReason:reason];
        _state = FKHelperAuthenticatedSessionStateInvalidated;
        _lastFailureReason = ([reason isKindOfClass:NSString.class] && reason.length) ? [reason copy] : @"session_invalidated";
        _activeSessionID = @"";
        [self appendAuditAction:FKAuditHelperIPCDisconnect result:@"success"
                     reasonCode:_lastFailureReason sessionID:sessionID];
    }
    [_lock unlock];
}
@end
