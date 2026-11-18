#import "FKHelperDeploymentTests.h"
#import "FKHelperDeploymentAssessment.h"

@implementation FKHelperDeploymentTests

+ (NSUInteger)checkCount { return 13; }

+ (NSDictionary *)completeEvidence {
    return @{
        @"helper_target_built": @YES,
        @"trusted_signing_anchor": @YES,
        @"helper_signature_verified": @YES,
        @"entitlements_separated_and_reviewed": @YES,
        @"mach_service_observed": @YES,
        @"peer_identity_verified": @YES,
        @"transport_device_verified": @YES,
        @"lifecycle_device_verified": @YES,
        @"rootless_build_verified": @YES,
        @"roothide_build_verified": @YES
    };
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // DEP1201：默认状态必须保持未就绪。
    NSDictionary *baseline = [FKHelperDeploymentAssessment defaultAssessment];
    if (![baseline[@"deploymentStatus"] isEqualToString:@"not_ready"]) {
        [failures addObject:@"DEP1201 缺少设备证据时必须未就绪"];
    }

    // DEP1202：默认报告不得开放部署、特权启动、IPC 或写操作。
    if ([baseline[@"daemonDeploymentAllowed"] boolValue] ||
        [baseline[@"privilegedLaunchAllowed"] boolValue] ||
        [baseline[@"realIPCReady"] boolValue] ||
        [baseline[@"writeOperationsAllowed"] boolValue]) {
        [failures addObject:@"DEP1202 默认安全边界必须全部关闭"];
    }

    // DEP1203：完整布尔证据可完成可行性评估，但不授权部署。
    NSDictionary *complete = [FKHelperDeploymentAssessment assessmentWithEvidence:[self completeEvidence]];
    if (![complete[@"deploymentStatus"] isEqualToString:@"feasibility_evidence_complete"] ||
        [complete[@"verifiedEvidenceCount"] unsignedIntegerValue] != 10 ||
        [complete[@"daemonDeploymentAllowed"] boolValue] ||
        [complete[@"writeOperationsAllowed"] boolValue]) {
        [failures addObject:@"DEP1203 完整证据不得自动授权部署或写操作"];
    }

    // DEP1204：任一必要证据缺失都不能通过。
    NSMutableDictionary *missing = [[self completeEvidence] mutableCopy];
    [missing removeObjectForKey:@"mach_service_observed"];
    NSDictionary *missingReport = [FKHelperDeploymentAssessment assessmentWithEvidence:missing];
    if (![missingReport[@"deploymentStatus"] isEqualToString:@"not_ready"] ||
        [missingReport[@"unverifiedEvidence"] count] != 1) {
        [failures addObject:@"DEP1204 缺少单项证据必须阻止就绪"];
    }

    // DEP1205：字符串形式的 YES 不得当作布尔证据。
    NSMutableDictionary *wrongType = [[self completeEvidence] mutableCopy];
    wrongType[@"helper_target_built"] = @"YES";
    NSDictionary *wrongTypeReport = [FKHelperDeploymentAssessment assessmentWithEvidence:wrongType];
    if (![wrongTypeReport[@"deploymentStatus"] isEqualToString:@"not_ready"] ||
        [wrongTypeReport[@"invalidEvidence"] count] != 1) {
        [failures addObject:@"DEP1205 错误类型证据必须拒绝"];
    }

    // DEP1206：非 0/1 数值不是合法布尔证据。
    NSMutableDictionary *numericType = [[self completeEvidence] mutableCopy];
    numericType[@"helper_target_built"] = @2;
    if ([[FKHelperDeploymentAssessment assessmentWithEvidence:numericType][@"invalidEvidence"] count] != 1) {
        [failures addObject:@"DEP1206 非布尔数值证据必须拒绝"];
    }

    // DEP1207：未知键视为拼写或协议错误，不得忽略后通过。
    NSMutableDictionary *unknown = [[self completeEvidence] mutableCopy];
    unknown[@"helper_target_built_typo"] = @YES;
    NSDictionary *unknownReport = [FKHelperDeploymentAssessment assessmentWithEvidence:unknown];
    if (![unknownReport[@"deploymentStatus"] isEqualToString:@"not_ready"] ||
        [unknownReport[@"unknownEvidenceKeys"] count] != 1) {
        [failures addObject:@"DEP1207 未知证据键必须阻止通过"];
    }

    // DEP1208：合法的反向域名服务名应通过格式检查。
    if (![FKHelperDeploymentAssessment isValidMachServiceName:@"com.filterkit.helper"]) {
        [failures addObject:@"DEP1208 合法 Mach Service 名称未通过"];
    }

    // DEP1209：路径不能作为服务名。
    if ([FKHelperDeploymentAssessment isValidMachServiceName:@"/var/jb/Library/Helper"]) {
        [failures addObject:@"DEP1209 路径不得作为 Mach Service 名称"];
    }

    // DEP1210：大写服务名拒绝，避免标识歧义。
    if ([FKHelperDeploymentAssessment isValidMachServiceName:@"Com.FilterKit.Helper"]) {
        [failures addObject:@"DEP1210 大写服务名必须拒绝"];
    }

    // DEP1211：空白与首尾空格拒绝。
    if ([FKHelperDeploymentAssessment isValidMachServiceName:@" com.filterkit.helper "]) {
        [failures addObject:@"DEP1211 带空白服务名必须拒绝"];
    }

    // DEP1212：长度超限拒绝。
    NSMutableString *longName = [NSMutableString stringWithString:@"com.filterkit."];
    while (longName.length <= 128) [longName appendString:@"x"];
    if ([FKHelperDeploymentAssessment isValidMachServiceName:longName]) {
        [failures addObject:@"DEP1212 超长服务名必须拒绝"];
    }

    // DEP1213：服务名标签不得以连字符结尾。
    if ([FKHelperDeploymentAssessment isValidMachServiceName:@"com.filterkit-.helper"]) {
        [failures addObject:@"DEP1213 服务名标签不得以连字符结尾"];
    }

    return failures.copy;
}

@end
