#import "FKHelperPeerTests.h"
#import "FKHelperPeerVerifier.h"
#import "FKHelperIdentity.h"
#import "FKHelperMetadata.h"
#import "FKHelperTrust.h"

@implementation FKHelperPeerTests

+ (NSUInteger)checkCount { return 11; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperPeerVerifier *verifier = [FKHelperPeerVerifier new];
    FKHelperMetadata *meta = [FKHelperMetadata new];
    meta.identifier = [FKHelperIdentity expectedIdentity].helperID;
    meta.exists = YES;
    meta.regularFile = YES;
    meta.executable = YES;

    FKHelperTrustReport *(^connectedReport)(BOOL, NSString *) = ^(BOOL identityOK, NSString *manifest) {
        FKHelperTrustReport *r = [FKHelperTrustReport new];
        r.ipcStatus = FKHelperIPCConnected;
        r.ipcVerified = YES;
        r.identityVerified = identityOK;
        r.signatureVerified = YES;
        r.signatureStatus = FKSignatureStatusValid;
        r.integrityStatus = FKHelperIntegrityVerified;
        r.permissionVerified = YES;
        r.permissionReadOnly = YES;
        r.permissionWrite = NO;
        r.manifestStatus = manifest;
        return r;
    };

    // PEER901：无连接 → NotConnected。
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:meta trustReport:nil] != FKHelperPeerNotConnected) {
        [failures addObject:@"PEER901 无连接应为 NotConnected"];
    }

    // PEER902：对端身份缺失 → Unverified。
    if ([verifier verifyPeerIdentity:nil metadata:meta trustReport:connectedReport(YES, @"verified")] != FKHelperPeerUnverified) {
        [failures addObject:@"PEER902 身份缺失应为 Unverified"];
    }

    // PEER903：Helper ID 不匹配 → Mismatch。
    FKHelperIdentity *badID = [FKHelperIdentity expectedIdentity];
    badID.helperID = @"com.other.helper";
    if ([verifier verifyPeerIdentity:badID metadata:meta trustReport:connectedReport(YES, @"verified")] != FKHelperPeerMismatch) {
        [failures addObject:@"PEER903 Helper ID 不符应为 Mismatch"];
    }

    // PEER904：Build ID 不匹配 → Mismatch。
    FKHelperIdentity *badBuild = [FKHelperIdentity expectedIdentity];
    badBuild.buildID = @"FKH-XXX";
    if ([verifier verifyPeerIdentity:badBuild metadata:meta trustReport:connectedReport(YES, @"verified")] != FKHelperPeerMismatch) {
        [failures addObject:@"PEER904 Build ID 不符应为 Mismatch"];
    }

    // PEER905：清单不可信 → Rejected。
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:meta trustReport:connectedReport(YES, @"unavailable")] != FKHelperPeerRejected) {
        [failures addObject:@"PEER905 清单不可信应为 Rejected"];
    }

    // PEER906：身份可信、标识与清单一致 → Verified。
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:meta trustReport:connectedReport(YES, @"verified")] != FKHelperPeerVerified) {
        [failures addObject:@"PEER906 可信对端应为 Verified"];
    }

    // PEER907：会话变化重新验证，验证器不保留旧会话结论。
    FKHelperTrustReport *disconnected = [FKHelperTrustReport new];
    disconnected.ipcStatus = FKHelperIPCUnavailable;
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:meta trustReport:disconnected] != FKHelperPeerNotConnected) {
        [failures addObject:@"PEER907 断开后应重新判定为 NotConnected"];
    }
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:meta trustReport:connectedReport(YES, @"verified")] != FKHelperPeerVerified) {
        [failures addObject:@"PEER907 新会话齐备应重新判定为 Verified"];
    }

    // PEER908：连接断开撤销 Peer Verified。
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:meta trustReport:disconnected] != FKHelperPeerNotConnected) {
        [failures addObject:@"PEER908 断开连接应撤销对端结论"];
    }

    // PEER909：签名不支持时不能提升为 Verified。
    FKHelperTrustReport *signatureUnknown = connectedReport(YES, @"verified");
    signatureUnknown.signatureVerified = NO;
    signatureUnknown.signatureStatus = FKSignatureStatusUnsupported;
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:meta trustReport:signatureUnknown] != FKHelperPeerUnverified) {
        [failures addObject:@"PEER909 签名 Unsupported 时不得 Verified"];
    }

    // PEER910：完整性缺少可信锚点时不能提升为 Verified。
    FKHelperTrustReport *integrityUnknown = connectedReport(YES, @"verified");
    integrityUnknown.integrityStatus = FKHelperIntegrityUnknown;
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:meta trustReport:integrityUnknown] != FKHelperPeerUnverified) {
        [failures addObject:@"PEER910 完整性 Unknown 时不得 Verified"];
    }

    // PEER911：系统工具候选不能被当成 Helper 对端。
    FKHelperMetadata *systemMeta = [FKHelperMetadata new];
    systemMeta.identifier = [FKHelperIdentity expectedIdentity].helperID;
    systemMeta.exists = YES; systemMeta.regularFile = YES; systemMeta.executable = YES;
    systemMeta.systemToolCandidate = YES;
    if ([verifier verifyPeerIdentity:[FKHelperIdentity expectedIdentity] metadata:systemMeta trustReport:connectedReport(YES, @"verified")] != FKHelperPeerMismatch) {
        [failures addObject:@"PEER911 系统工具候选不得通过 Peer 验证"];
    }

    return failures.copy;
}

@end
