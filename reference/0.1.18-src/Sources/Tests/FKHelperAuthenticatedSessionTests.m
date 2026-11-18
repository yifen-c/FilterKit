#import "FKHelperAuthenticatedSessionTests.h"
#import "FKHelperAuthenticatedSessionManager.h"
#import "FKHelperPeerBinding.h"
#import "FKHelperKeyLifecycle.h"
#import "FKHelperKeyConfirmation.h"

@implementation FKHelperAuthenticatedSessionTests
+ (NSUInteger)checkCount { return 15; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSString *digest = @"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:200000];
    FKHelperAuthenticatedSessionManager *manager =
        [[FKHelperAuthenticatedSessionManager alloc] initWithAuditManager:nil keyLifecycle:nil
                                                          maximumLifetime:600 idleTimeout:60];
    if (manager.state != FKHelperAuthenticatedSessionStateIdle || manager.readOnlySessionEstablished)
        [failures addObject:@"ASM1901 初始状态不得视为认证会话"];

    FKHelperSessionKey *key = [manager createSessionKeyAtDate:now];
    FKHelperPeerBinding *binding = [[FKHelperPeerBinding alloc] initWithSessionID:@"session-a"
        clientID:@"com.filterkit.manager" helperID:@"com.filterkit.helper" helperBuildID:@"FKH-0118"
        credentialDigest:digest transcriptDigest:digest];
    FKHelperKeyConfirmation *confirmation = [FKHelperKeyConfirmation new];
    NSString *clientProof = [confirmation proofForRole:FKHelperConfirmationRoleClient
        sessionID:@"session-a" transcriptDigest:digest key:key.keyData];
    NSString *helperProof = [confirmation proofForRole:FKHelperConfirmationRoleHelper
        sessionID:@"session-a" transcriptDigest:digest key:key.keyData];

    if (![manager establishWithPeerBinding:binding expectedHelperID:@"com.filterkit.helper"
        expectedBuildID:@"FKH-0118" expectedCredentialDigest:digest key:key
        clientProof:clientProof helperProof:helperProof source:@"mock" date:now error:nil] ||
        !manager.readOnlySessionEstablished)
        [failures addObject:@"ASM1902 完整 Peer 与双向确认应建立本地只读会话"];

    if ([manager establishWithPeerBinding:binding expectedHelperID:@"com.filterkit.helper"
        expectedBuildID:@"FKH-0118" expectedCredentialDigest:digest key:key
        clientProof:clientProof helperProof:helperProof source:@"mock" date:now error:nil])
        [failures addObject:@"ASM1903 活跃会话不得被重复确认或覆盖"];

    if (![manager touchAtDate:[now dateByAddingTimeInterval:20]])
        [failures addObject:@"ASM1904 空闲期限内触达应成功"];

    [manager invalidateWithReason:@"transport_disconnected"];
    if (manager.state != FKHelperAuthenticatedSessionStateInvalidated ||
        manager.readOnlySessionEstablished || manager.activeSessionID.length != 0)
        [failures addObject:@"ASM1905 断线必须清除会话授权状态"];
    if (key.state != FKHelperKeyStateRevoked)
        [failures addObject:@"ASM1906 断线必须撤销会话密钥"];

    FKHelperSessionKey *nextKey = [manager createSessionKeyAtDate:now];
    FKHelperPeerBinding *nextBinding = [[FKHelperPeerBinding alloc] initWithSessionID:@"session-b"
        clientID:@"com.filterkit.manager" helperID:@"com.filterkit.helper" helperBuildID:@"FKH-0118"
        credentialDigest:digest transcriptDigest:digest];
    NSString *nextClient = [confirmation proofForRole:FKHelperConfirmationRoleClient
        sessionID:@"session-b" transcriptDigest:digest key:nextKey.keyData];
    NSString *nextHelper = [confirmation proofForRole:FKHelperConfirmationRoleHelper
        sessionID:@"session-b" transcriptDigest:digest key:nextKey.keyData];
    if (![manager establishWithPeerBinding:nextBinding expectedHelperID:@"com.filterkit.helper"
        expectedBuildID:@"FKH-0118" expectedCredentialDigest:digest key:nextKey
        clientProof:nextClient helperProof:nextHelper source:@"mock"
        date:[now dateByAddingTimeInterval:30] error:nil])
        [failures addObject:@"ASM1907 旧会话失效后允许全新会话重新握手"];

    [manager invalidateWithReason:@"prepare_identity_mismatch"];
    FKHelperAuthenticatedSessionManager *identityManager =
        [[FKHelperAuthenticatedSessionManager alloc] initWithAuditManager:nil keyLifecycle:nil
                                                          maximumLifetime:600 idleTimeout:60];
    FKHelperSessionKey *identityKey = [identityManager createSessionKeyAtDate:now];
    FKHelperPeerBinding *wrongBuildBinding = [[FKHelperPeerBinding alloc] initWithSessionID:@"wrong-build"
        clientID:@"com.filterkit.manager" helperID:@"com.filterkit.helper" helperBuildID:@"FKH-OLD"
        credentialDigest:digest transcriptDigest:digest];
    NSString *identityClient = [confirmation proofForRole:FKHelperConfirmationRoleClient
        sessionID:@"wrong-build" transcriptDigest:digest key:identityKey.keyData];
    NSString *identityHelper = [confirmation proofForRole:FKHelperConfirmationRoleHelper
        sessionID:@"wrong-build" transcriptDigest:digest key:identityKey.keyData];
    if ([identityManager establishWithPeerBinding:wrongBuildBinding expectedHelperID:@"com.filterkit.helper"
        expectedBuildID:@"FKH-0118" expectedCredentialDigest:digest key:identityKey
        clientProof:identityClient helperProof:identityHelper source:@"mock"
        date:[now dateByAddingTimeInterval:31] error:nil])
        [failures addObject:@"ASM1908 Helper Build 错配必须拒绝"];
    if (identityKey.state != FKHelperKeyStateRevoked)
        [failures addObject:@"ASM1908A 身份错配必须撤销候选密钥"];

    [manager invalidateWithReason:@"test_reset"];
    FKHelperAuthenticatedSessionManager *badManager =
        [[FKHelperAuthenticatedSessionManager alloc] initWithAuditManager:nil keyLifecycle:nil
                                                          maximumLifetime:600 idleTimeout:60];
    FKHelperSessionKey *badKey = [badManager createSessionKeyAtDate:now];
    FKHelperPeerBinding *badBinding = [[FKHelperPeerBinding alloc] initWithSessionID:@"bad"
        clientID:@"com.filterkit.manager" helperID:@"com.filterkit.helper" helperBuildID:@"FKH-0118"
        credentialDigest:digest transcriptDigest:digest];
    if ([badManager establishWithPeerBinding:badBinding expectedHelperID:@"com.filterkit.helper"
        expectedBuildID:@"FKH-0118" expectedCredentialDigest:digest key:badKey
        clientProof:@"invalid" helperProof:@"invalid" source:@"mock" date:now error:nil])
        [failures addObject:@"ASM1909 错误确认码必须拒绝会话"];
    if (badManager.state != FKHelperAuthenticatedSessionStateFailed ||
        badKey.state != FKHelperKeyStateRevoked)
        [failures addObject:@"ASM1910 认证失败必须进入失败态并撤销密钥"];

    FKHelperAuthenticatedSessionManager *unsupported =
        [[FKHelperAuthenticatedSessionManager alloc] initWithAuditManager:nil keyLifecycle:nil
                                                          maximumLifetime:600 idleTimeout:60];
    FKHelperSessionKey *unsupportedKey = [unsupported createSessionKeyAtDate:now];
    if ([unsupported establishWithPeerBinding:binding expectedHelperID:@"com.filterkit.helper"
        expectedBuildID:@"FKH-0118" expectedCredentialDigest:digest key:unsupportedKey
        clientProof:clientProof helperProof:helperProof source:@"real_ipc" date:now error:nil])
        [failures addObject:@"ASM1911 未接入真实 Transport 时不得伪称 real_ipc"];
    if (unsupported.readOnlySessionEstablished)
        [failures addObject:@"ASM1912 非法来源不得建立会话授权"];

    FKHelperAuthenticatedSessionManager *concurrent =
        [[FKHelperAuthenticatedSessionManager alloc] initWithAuditManager:nil keyLifecycle:nil
                                                          maximumLifetime:600 idleTimeout:60];
    FKHelperSessionKey *concurrentKey = [concurrent createSessionKeyAtDate:now];
    FKHelperPeerBinding *concurrentBinding = [[FKHelperPeerBinding alloc] initWithSessionID:@"race"
        clientID:@"com.filterkit.manager" helperID:@"com.filterkit.helper" helperBuildID:@"FKH-0118"
        credentialDigest:digest transcriptDigest:digest];
    NSString *raceClient = [confirmation proofForRole:FKHelperConfirmationRoleClient
        sessionID:@"race" transcriptDigest:digest key:concurrentKey.keyData];
    NSString *raceHelper = [confirmation proofForRole:FKHelperConfirmationRoleHelper
        sessionID:@"race" transcriptDigest:digest key:concurrentKey.keyData];
    __block NSUInteger winners = 0;
    dispatch_group_t group = dispatch_group_create();
    for (NSUInteger i = 0; i < 2; i++) {
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            BOOL won = [concurrent establishWithPeerBinding:concurrentBinding
                expectedHelperID:@"com.filterkit.helper" expectedBuildID:@"FKH-0118"
                expectedCredentialDigest:digest key:concurrentKey clientProof:raceClient
                helperProof:raceHelper source:@"mock" date:now error:nil];
            if (won) @synchronized (concurrent) { winners += 1; }
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    if (winners != 1)
        [failures addObject:@"ASM1913 并发握手竞争只能有一个成功建立者"];
    if (!concurrent.readOnlySessionEstablished)
        [failures addObject:@"ASM1914 并发竞争结束后会话状态必须一致"];

    return failures.copy;
}
@end
