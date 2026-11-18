#import "FKSecurityEvent.h"

@implementation FKSecurityEvent

+ (NSString *)typeCodeForType:(FKSecurityEventType)type {
    switch (type) {
        case FKSecurityEventTypeEnvironment: return @"environment_detect";
        case FKSecurityEventTypeInjector: return @"injector_identify";
        case FKSecurityEventTypeHelperDiscover: return @"helper_discover";
        case FKSecurityEventTypeHelperIdentity: return @"helper_identity";
        case FKSecurityEventTypeHelperSignature: return @"helper_signature";
        case FKSecurityEventTypeHelperPermission: return @"helper_permission";
        case FKSecurityEventTypeIPC: return @"ipc_verify";
        case FKSecurityEventTypeGateEvaluation: return @"gate_evaluation";
        case FKSecurityEventTypeGateRejection: return @"gate_rejection";
        case FKSecurityEventTypeScanStarted: return @"scan_started";
        case FKSecurityEventTypeScanCompleted: return @"scan_completed";
        case FKSecurityEventTypeBackup: return @"backup_result";
        case FKSecurityEventTypeTestExecution: return @"test_execution";
        case FKSecurityEventTypeReportExport: return @"report_export";
        case FKSecurityEventTypeAppOpened: return @"app_opened";
        case FKSecurityEventTypeAppSearched: return @"app_searched";
        case FKSecurityEventTypePluginSelected: return @"plugin_selected";
        case FKSecurityEventTypeAssociationPreviewed: return @"association_previewed";
        case FKSecurityEventTypeAssociationCreated: return @"association_created";
        case FKSecurityEventTypeAssociationRemoved: return @"association_removed";
        case FKSecurityEventTypeInjectionPreviewCreated: return @"injection_preview_created";
        case FKSecurityEventTypeCompatibilityChecked: return @"compatibility_checked";
        case FKSecurityEventTypeOperationDenied: return @"operation_denied";
        case FKSecurityEventTypeTransactionCreated: return @"transaction_created";
        case FKSecurityEventTypeTransactionCompleted: return @"transaction_completed";
        case FKSecurityEventTypeTransactionFailed: return @"transaction_failed";
        case FKSecurityEventTypeRollbackRequired: return @"rollback_required";
        case FKSecurityEventTypeRollbackCompleted: return @"rollback_completed";
        case FKSecurityEventTypeVerificationPassed: return @"verification_passed";
        case FKSecurityEventTypeVerificationFailed: return @"verification_failed";
        case FKSecurityEventTypeConfigurationBackupCreated: return @"configuration_backup_created";
        case FKSecurityEventTypeManifestValidation: return @"manifest_validation";
        case FKSecurityEventTypeIntegrityCheck: return @"integrity_check";
        case FKSecurityEventTypeProtocolValidation: return @"protocol_validation";
        case FKSecurityEventTypeCapabilityEvaluation: return @"capability_evaluation";
        case FKSecurityEventTypeOperationRejected: return @"operation_rejected";
    }
    return @"unknown";
}

+ (instancetype)eventWithType:(FKSecurityEventType)type
                        target:(NSString *)target
                        result:(NSString *)result
                        reason:(NSString *)reason
                      evidence:(NSDictionary *)evidence {
    FKSecurityEvent *event = [self new];
    event.eventID = [[NSUUID UUID] UUIDString];
    event.eventType = [self typeCodeForType:type];
    event.timestamp = [NSDate date];
    event.target = target ?: @"";
    event.result = result ?: @"unknown";
    event.reason = reason ?: @"";
    event.evidence = evidence ?: @{};
    return event;
}

+ (instancetype)eventFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKSecurityEvent *event = [self new];
    event.eventID = dict[@"event_id"] ?: [[NSUUID UUID] UUIDString];
    event.eventType = dict[@"event_type"] ?: @"unknown";
    event.target = dict[@"target"] ?: @"";
    event.result = dict[@"result"] ?: @"unknown";
    event.reason = dict[@"reason"] ?: @"";
    event.evidence = [dict[@"evidence"] isKindOfClass:NSDictionary.class] ? dict[@"evidence"] : @{};
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    NSString *timestampText = [dict[@"timestamp"] isKindOfClass:NSString.class] ? dict[@"timestamp"] : nil;
    event.timestamp = timestampText ? [formatter dateFromString:timestampText] : [NSDate date];
    return event;
}

- (NSDictionary *)JSONDictionary {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    return @{
        @"event_id": self.eventID ?: @"",
        @"event_type": self.eventType ?: @"unknown",
        @"timestamp": [formatter stringFromDate:self.timestamp ?: [NSDate date]],
        @"target": self.target ?: @"",
        @"result": self.result ?: @"unknown",
        @"reason": self.reason ?: @"",
        @"evidence": self.evidence ?: @{}
    };
}

@end
