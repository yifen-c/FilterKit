#import "FKCapabilityEvaluator.h"
#import "FKHelperTrust.h"
#import "FKHelperCapabilities.h"

@interface FKCapabilityEvaluator ()
@property (nonatomic, copy, readwrite) NSArray<NSString *> *denyReasons;
@end

@implementation FKCapabilityEvaluator

- (BOOL)canPerformCapability:(NSString *)capability
                  trustReport:(FKHelperTrustReport *)report
                 capabilities:(FKHelperCapabilities *)capabilities {
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];

    // 1. 能力键必须存在且属于只读白名单；写能力与未知能力直接拒绝。
    if (capability.length == 0) {
        [reasons addObject:@"unknown_capability"];
    } else if (![[FKHelperCapabilities readOnlyWhitelist] containsObject:capability]) {
        [reasons addObject:@"capability_denied"];
    } else if (![capabilities supportsCapability:capability]) {
        [reasons addObject:@"capability_not_registered"];
    }

    // 2. 信任链：身份 / 清单 / 完整性 / 对端通道任一未验证，均不授权。
    if (!report) {
        [reasons addObject:@"helper_identity_unknown"];
    } else {
        if (!report.identityVerified) [reasons addObject:@"identity_unverified"];
        if (![report.manifestStatus isEqualToString:@"verified"]) [reasons addObject:@"manifest_unverified"];
        BOOL signatureOK = report.signatureVerified &&
            (report.signatureStatus == FKSignatureStatusValid || report.signatureStatus == FKSignatureStatusVerified);
        if (!signatureOK) [reasons addObject:@"signature_unverified"];
        if (report.integrityStatus != FKHelperIntegrityVerified) [reasons addObject:@"integrity_unverified"];
        if (!report.permissionVerified || !report.permissionReadOnly || report.permissionWrite) {
            [reasons addObject:@"permission_unverified"];
        }
        if (!report.ipcVerified || report.ipcStatus != FKHelperIPCConnected) [reasons addObject:@"peer_unverified"];
    }

    self.denyReasons = reasons.copy;
    return reasons.count == 0;
}

@end
