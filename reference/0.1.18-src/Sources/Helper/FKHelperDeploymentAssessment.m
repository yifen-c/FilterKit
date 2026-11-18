#import "FKHelperDeploymentAssessment.h"

static NSArray<NSString *> *FKRequiredDeploymentEvidence(void) {
    return @[
        @"helper_target_built",
        @"trusted_signing_anchor",
        @"helper_signature_verified",
        @"entitlements_separated_and_reviewed",
        @"mach_service_observed",
        @"peer_identity_verified",
        @"transport_device_verified",
        @"lifecycle_device_verified",
        @"rootless_build_verified",
        @"roothide_build_verified"
    ];
}

static BOOL FKStrictBoolean(id value, BOOL *result) {
    if (![value isKindOfClass:NSNumber.class]) return NO;
    double number = [(NSNumber *)value doubleValue];
    if (number != 0.0 && number != 1.0) return NO;
    if (result) *result = [(NSNumber *)value boolValue];
    return YES;
}

static BOOL FKReadEvidenceFlag(NSDictionary *input, NSString *key) {
    BOOL value = NO;
    return FKStrictBoolean(input[key], &value) && value;
}

@implementation FKHelperDeploymentAssessment

+ (BOOL)isValidMachServiceName:(nullable NSString *)serviceName {
    if (![serviceName isKindOfClass:NSString.class]) return NO;
    NSString *value = [serviceName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (value.length == 0 || value.length > 128 || ![value isEqualToString:serviceName]) return NO;
    NSError *error = nil;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^[a-z](?:[a-z0-9-]*[a-z0-9])?(?:\\.[a-z](?:[a-z0-9-]*[a-z0-9])?){2,}$"
                                                                                 options:0
                                                                                   error:&error];
    if (error || !expression) return NO;
    return [expression numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)] == 1;
}

+ (NSDictionary *)assessmentWithEvidence:(nullable NSDictionary *)evidence {
    NSDictionary *input = [evidence isKindOfClass:NSDictionary.class] ? evidence : @{};
    NSArray<NSString *> *required = FKRequiredDeploymentEvidence();
    NSSet<NSString *> *known = [NSSet setWithArray:required];
    NSMutableArray<NSString *> *unknownKeys = [NSMutableArray array];
    for (id key in input.allKeys) {
        if (![key isKindOfClass:NSString.class] || ![known containsObject:key]) {
            [unknownKeys addObject:[key description] ?: @"<invalid-key>"];
        }
    }
    [unknownKeys sortUsingSelector:@selector(compare:)];

    NSMutableArray<NSDictionary *> *checks = [NSMutableArray arrayWithCapacity:required.count];
    NSMutableArray<NSString *> *unverified = [NSMutableArray array];
    NSMutableArray<NSString *> *invalid = [NSMutableArray array];
    BOOL allVerified = unknownKeys.count == 0;
    if (unknownKeys.count > 0) {
        // 未知键通常表示拼写错误或版本错配，不能忽略后判定证据齐全。
        allVerified = NO;
    }

    for (NSString *key in required) {
        id raw = input[key];
        BOOL verified = NO;
        BOOL validType = FKStrictBoolean(raw, &verified);
        NSString *status = raw == nil ? @"missing" : (validType ? (verified ? @"verified" : @"not_verified") : @"invalid_type");
        if (raw == nil) {
            // 缺少证据属于未验证；错误类型单独归类，便于报告准确定位。
            [unverified addObject:key];
            allVerified = NO;
        } else if (!validType) {
            [invalid addObject:key];
            allVerified = NO;
        } else if (!verified) {
            [unverified addObject:key];
            allVerified = NO;
        }
        [checks addObject:@{
            @"evidence": key,
            @"status": status,
            @"required": @YES
        }];
    }

    return @{
        @"schemaVersion": @1,
        @"assessmentType": @"helper_deployment_feasibility",
        @"deploymentStatus": allVerified ? @"feasibility_evidence_complete" : @"not_ready",
        @"requiredEvidenceCount": @(required.count),
        @"verifiedEvidenceCount": @(required.count - unverified.count - invalid.count),
        @"checks": checks.copy,
        @"unverifiedEvidence": unverified.copy,
        @"invalidEvidence": invalid.copy,
        @"unknownEvidenceKeys": unknownKeys.copy,
        @"helperTargetPresent": @(FKReadEvidenceFlag(input, @"helper_target_built")),
        @"machServiceObserved": @(FKReadEvidenceFlag(input, @"mach_service_observed")),
        @"daemonDeploymentAllowed": @NO,
        @"privilegedLaunchAllowed": @NO,
        @"realIPCReady": @NO,
        @"writeOperationsAllowed": @NO,
        @"nextStep": allVerified ? @"manual_security_review_and_explicit_release_gate" : @"complete_missing_device_evidence"
    };
}

+ (NSDictionary *)defaultAssessment {
    return [self assessmentWithEvidence:@{}];
}

@end
