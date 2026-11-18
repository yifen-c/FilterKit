#import "FKOperationPolicy.h"

@implementation FKOperationPolicy

+ (instancetype)defaultPolicy {
    FKOperationPolicy *policy = [self new];
    policy.mode = @"preview_only";
    // 0.1.15 不开放真实启停；真实操作须待可信 Helper 端点、协议与授权通道独立验收后决定。
    policy.securityMode = FKOperationModePreviewOnly;
    policy.allowsRealOperation = NO;
    policy.requiredRequirementIDs = @[
        @"environment", @"injector", @"injector_compatibility", @"identity", @"app_identity",
        @"path", @"ownership", @"integrity", @"target_readable", @"scope",
        @"helper_identity", @"helper_signature", @"helper_permission",
        @"ipc", @"protocol_version", @"backup", @"backup_verified",
        @"audit", @"authorization"
    ];
    return policy;
}

+ (NSString *)securityModeText:(FKOperationMode)mode {
    switch (mode) {
        case FKOperationModeReadOnly: return @"read_only";
        case FKOperationModePreviewOnly: return @"preview_only";
        case FKOperationModeBackupWrite: return @"backup_write";
        case FKOperationModeAuthorizedManagement: return @"authorized_management";
        default: return @"preview_only";
    }
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"mode": self.mode ?: @"preview_only",
        @"security_mode": [FKOperationPolicy securityModeText:self.securityMode],
        @"allows_real_operation": @(self.allowsRealOperation),
        @"required_requirements": self.requiredRequirementIDs ?: @[]
    };
}

@end
