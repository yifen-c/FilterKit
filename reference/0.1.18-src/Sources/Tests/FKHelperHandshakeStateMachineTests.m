#import "FKHelperHandshakeStateMachineTests.h"
#import "FKHelperHandshakeStateMachine.h"

@implementation FKHelperHandshakeStateMachineTests

+ (NSUInteger)checkCount { return 10; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperHandshakeStateMachine *machine = [FKHelperHandshakeStateMachine new];
    NSError *error = nil;

    if (machine.phase != FKHelperHandshakePhaseIdle) [failures addObject:@"HSM1601 初始状态错误"];
    if ([machine advanceToPhase:FKHelperHandshakePhaseProtocolNegotiated
                       evidence:@{@"protocol_negotiated": @YES} error:&error]) {
        [failures addObject:@"HSM1602 不得跳过 Peer 验证"];
    }
    if ([machine advanceToPhase:FKHelperHandshakePhasePeerVerified
                       evidence:@{@"peer_verified": @"YES"} error:nil]) {
        [failures addObject:@"HSM1603 字符串证据不得通过"];
    }
    if (![machine advanceToPhase:FKHelperHandshakePhasePeerVerified evidence:@{@"peer_verified": @YES} error:nil]) {
        [failures addObject:@"HSM1604 Peer 验证状态推进失败"];
    }
    if (![machine advanceToPhase:FKHelperHandshakePhaseProtocolNegotiated evidence:@{@"protocol_negotiated": @YES} error:nil]) {
        [failures addObject:@"HSM1605 协议协商状态推进失败"];
    }
    if (![machine advanceToPhase:FKHelperHandshakePhaseTranscriptVerified evidence:@{@"transcript_verified": @YES} error:nil]) {
        [failures addObject:@"HSM1606 转录验证状态推进失败"];
    }
    if (![machine advanceToPhase:FKHelperHandshakePhaseKeyDerived evidence:@{@"key_derived": @YES} error:nil]) {
        [failures addObject:@"HSM1607 密钥派生状态推进失败"];
    }
    if (![machine advanceToPhase:FKHelperHandshakePhaseClientConfirmed evidence:@{@"client_confirmation_verified": @YES} error:nil]) {
        [failures addObject:@"HSM1608 客户端确认状态推进失败"];
    }
    if (![machine advanceToPhase:FKHelperHandshakePhaseEstablished evidence:@{@"helper_confirmation_verified": @YES} error:nil] ||
        machine.phase != FKHelperHandshakePhaseEstablished) {
        [failures addObject:@"HSM1609 双向确认后应建立会话"];
    }
    [machine expire];
    if (machine.phase != FKHelperHandshakePhaseExpired) [failures addObject:@"HSM1610 会话过期状态错误"];
    return failures.copy;
}

@end
