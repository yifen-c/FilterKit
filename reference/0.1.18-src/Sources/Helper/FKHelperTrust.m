#import "FKHelperTrust.h"
#import "FKHelperEvidence.h"

static NSString *FKSignatureStatusCode(FKSignatureStatus status) {
    switch (status) {
        case FKSignatureStatusValid:
        case FKSignatureStatusVerified: return @"verified";
        case FKSignatureStatusInvalid: return @"invalid";
        case FKSignatureStatusAdHoc: return @"adhoc";
        case FKSignatureStatusUnsigned: return @"unsigned";
        case FKSignatureStatusUnsupported: return @"unsupported";
        case FKSignatureStatusUnknown:
        case FKSignatureStatusUnverified: return @"unknown";
    }
    return @"unknown";
}

static NSString *FKIdentityStatusCode(FKHelperIdentityStatus status) {
    switch (status) {
        case FKHelperIdentityVerified: return @"verified";
        case FKHelperIdentityMismatch: return @"mismatch";
        case FKHelperIdentityIncomplete: return @"incomplete";
        case FKHelperIdentityUnknown: return @"unknown";
    }
    return @"unknown";
}

static NSString *FKIntegrityStatusCode(FKHelperIntegrityStatus status) {
    switch (status) {
        case FKHelperIntegrityVerified: return @"verified";
        case FKHelperIntegrityMismatch: return @"mismatch";
        case FKHelperIntegrityUnavailable: return @"unavailable";
        case FKHelperIntegrityUnknown: return @"unknown";
    }
    return @"unknown";
}

@implementation FKHelperTrustReport

+ (NSString *)stateTextForState:(FKHelperTrustState)state {
    switch (state) {
        case FKHelperTrustStateNotFound: return @"未发现";
        case FKHelperTrustStateDiscovered: return @"已发现，证据不足";
        case FKHelperTrustStateIdentityVerified: return @"身份已验证";
        case FKHelperTrustStateSignatureVerified: return @"签名已验证";
        case FKHelperTrustStatePermissionVerified: return @"权限已验证";
        case FKHelperTrustStateIPCVerified: return @"通信协议已验证";
        case FKHelperTrustStateOperationReady: return @"准入就绪";
        case FKHelperTrustStateRejected: return @"验证失败，已拒绝";
    }
    return @"未知";
}

+ (NSString *)stateCodeForState:(FKHelperTrustState)state {
    switch (state) {
        case FKHelperTrustStateNotFound: return @"NOT_FOUND";
        case FKHelperTrustStateDiscovered: return @"DISCOVERED";
        case FKHelperTrustStateIdentityVerified: return @"IDENTITY_VERIFIED";
        case FKHelperTrustStateSignatureVerified: return @"SIGNATURE_VERIFIED";
        case FKHelperTrustStatePermissionVerified: return @"PERMISSION_VERIFIED";
        case FKHelperTrustStateIPCVerified: return @"IPC_VERIFIED";
        case FKHelperTrustStateOperationReady: return @"OPERATION_READY";
        case FKHelperTrustStateRejected: return @"REJECTED";
    }
    return @"UNKNOWN";
}

+ (NSString *)identityTextForStatus:(FKHelperIdentityStatus)status {
    switch (status) {
        case FKHelperIdentityVerified: return @"已验证";
        case FKHelperIdentityMismatch: return @"标识不符";
        case FKHelperIdentityIncomplete: return @"信息不完整";
        case FKHelperIdentityUnknown: return @"未知";
    }
    return @"未知";
}

+ (NSString *)integrityTextForStatus:(FKHelperIntegrityStatus)status {
    switch (status) {
        case FKHelperIntegrityVerified: return @"已验证";
        case FKHelperIntegrityMismatch: return @"不匹配";
        case FKHelperIntegrityUnavailable: return @"不可用";
        case FKHelperIntegrityUnknown: return @"未知";
    }
    return @"未知";
}

- (NSDictionary *)JSONDictionary {
    NSDictionary<NSString *, NSNumber *> *capabilities = self.capabilities ?: @{
        @"local.inspect": @(YES),
        @"helper.info": @(NO),
        @"plugin.list": @(NO),
        @"plugin.inspect": @(NO),
        @"config.inspect": @(NO),
        @"plugin.enable": @(NO),
        @"plugin.disable": @(NO),
        @"config.write": @(NO)
    };
    return @{
        @"schemaVersion": @(2),
        @"path": self.path ?: @"",
        @"package_id": self.packageID ?: @"",
        @"version": self.version ?: @"",
        @"helper": @{
            @"helperID": self.helperID ?: @"",
            @"version": self.version ?: @"",
            @"buildID": self.buildID ?: @""
        },
        @"manifest": @{ @"status": self.manifestStatus ?: @"unavailable" },
        @"capabilities": capabilities,
        @"permissions": @{
            @"readOnly": @(self.permissionReadOnly),
            @"write": @(self.permissionWrite)
        },
        @"state": [FKHelperTrustReport stateCodeForState:self.state],
        @"state_text": [FKHelperTrustReport stateTextForState:self.state],
        @"discovery": @{
            @"code": [FKHelperDiscovery statusCodeForStatus:self.discoveryStatus],
            @"text": [FKHelperDiscovery statusTextForStatus:self.discoveryStatus]
        },
        @"identity": @{
            @"status": FKIdentityStatusCode(self.identityStatus),
            @"verified": @(self.identityVerified)
        },
        @"signature": @{ @"status": FKSignatureStatusCode(self.signatureStatus) },
        @"integrity": @{ @"status": FKIntegrityStatusCode(self.integrityStatus) },
        @"ipc": @{
            @"code": [FKHelperIPCHandshake statusCodeForStatus:self.ipcStatus],
            @"text": [FKHelperIPCHandshake statusTextForStatus:self.ipcStatus]
        },
        @"permission": @{
            @"read_only": @(self.permissionReadOnly),
            @"write": @(self.permissionWrite)
        },
        @"real_operation_allowed": @(self.realOperationAllowed),
        @"reason_codes": self.reasonCodes ?: @[],
        @"identity_verified": @(self.identityVerified),
        @"signature_verified": @(self.signatureVerified),
        @"permission_verified": @(self.permissionVerified),
        @"ipc_verified": @(self.ipcVerified),
        @"reasons": self.reasons ?: @[],
        @"checked_at": [[NSISO8601DateFormatter new] stringFromDate:self.checkedAt ?: [NSDate date]],
        @"evidence": self.evidence ? [self.evidence JSONDictionary] : @{}
    };
}

@end
