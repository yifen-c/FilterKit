#import "FKHelperPeerVerifier.h"
#import "FKHelperIdentity.h"
#import "FKHelperMetadata.h"
#import "FKHelperTrust.h"

@implementation FKHelperPeerVerifier

- (FKHelperPeerStatus)verifyPeerIdentity:(FKHelperIdentity *)identity
                                metadata:(FKHelperMetadata *)metadata
                             trustReport:(FKHelperTrustReport *)trustReport {
    FKHelperIdentity *expected = [FKHelperIdentity expectedIdentity];

    if (!trustReport || trustReport.ipcStatus != FKHelperIPCConnected || !trustReport.ipcVerified) {
        return FKHelperPeerNotConnected;
    }

    if (!identity || !metadata) return FKHelperPeerUnverified;

    // 身份字段必须整体匹配；不能只比较 helperID / buildID 而忽略组件、版本和协议。
    if (![identity isStructurallyValid] || ![identity matchesIdentity:expected]) {
        return FKHelperPeerMismatch;
    }
    if (metadata.identifier.length == 0 || ![metadata.identifier isEqualToString:expected.helperID] ||
        !metadata.exists || !metadata.regularFile || !metadata.executable || metadata.systemToolCandidate) {
        return FKHelperPeerMismatch;
    }

    // Peer Verified 需要独立的发布清单、签名、完整性与权限证据。
    BOOL signatureOK = trustReport.signatureVerified &&
        (trustReport.signatureStatus == FKSignatureStatusValid ||
         trustReport.signatureStatus == FKSignatureStatusVerified);
    BOOL integrityOK = trustReport.integrityStatus == FKHelperIntegrityVerified;
    BOOL permissionOK = trustReport.permissionVerified && trustReport.permissionReadOnly && !trustReport.permissionWrite;
    BOOL manifestOK = [trustReport.manifestStatus isEqualToString:@"verified"];

    if (!manifestOK) return FKHelperPeerRejected;
    if (!signatureOK || !integrityOK || !permissionOK || !trustReport.identityVerified) {
        return FKHelperPeerUnverified;
    }
    return FKHelperPeerVerified;
}

+ (NSString *)statusCodeForStatus:(FKHelperPeerStatus)status {
    switch (status) {
        case FKHelperPeerNotConnected: return @"not_connected";
        case FKHelperPeerUnverified: return @"unverified";
        case FKHelperPeerVerified:    return @"verified";
        case FKHelperPeerMismatch:    return @"mismatch";
        case FKHelperPeerRejected:     return @"rejected";
        case FKHelperPeerUnknown:
        default:                      return @"unknown";
    }
}

+ (NSString *)statusTextForStatus:(FKHelperPeerStatus)status {
    switch (status) {
        case FKHelperPeerNotConnected: return @"未连接";
        case FKHelperPeerUnverified: return @"对端未验证";
        case FKHelperPeerVerified:    return @"对端已验证";
        case FKHelperPeerMismatch:    return @"对端标识不符";
        case FKHelperPeerRejected:     return @"对端已拒绝";
        case FKHelperPeerUnknown:
        default:                      return @"未知";
    }
}

@end
