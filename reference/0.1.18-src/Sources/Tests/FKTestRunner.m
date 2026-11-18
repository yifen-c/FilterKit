#import "FKTestRunner.h"
#import "FKModelTests.h"
#import "FKBackupTests.h"
#import "FKJSONTests.h"
#import "FKOperationTests.h"
#import "FKHelperTrustTests.h"
#import "FKHelperIdentityTests.h"
#import "FKHelperMetadataTests.h"
#import "FKHelperManifestTests.h"
#import "FKHelperIntegrityTests.h"
#import "FKHelperProtocolTests.h"
#import "FKHelperTransportTests.h"
#import "FKHelperReportTests.h"
#import "FKHelperCapabilityTests.h"
#import "FKHelperGateTests.h"
#import "FKHelperDiscoveryTests.h"
#import "FKHelperPeerTests.h"
#import "FKHelperHandshakeTests.h"
#import "FKHelperRouterTests.h"
#import "FKHelperPluginTests.h"
#import "FKHelperConfigurationTests.h"
#import "FKHelperAuditTests.h"
#import "FKHelperBoundaryTests.h"
#import "FKHelperDeploymentTests.h"
#import "FKHelperAuthenticationTests.h"
#import "FKHelperReplayTests.h"
#import "FKHelperFrameTests.h"
#import "FKHelperTransportAssessmentTests.h"
#import "FKHelperKeyDerivationTests.h"
#import "FKHelperKeyLifecycleTests.h"
#import "FKHelperProtocolNegotiationTests.h"
#import "FKHelperHandshakeTranscriptTests.h"
#import "FKHelperSessionLifecycleTests.h"
#import "FKHelperPeerBindingTests.h"
#import "FKHelperHandshakeStateMachineTests.h"
#import "FKHelperKeyConfirmationTests.h"
#import "FKHelperAuthenticatedSessionTests.h"
#import "FKHelperTrustAnchorTests.h"
#import "FKHelperReleaseVerifierTests.h"
#import "FKHelperPeerCredentialTests.h"
#import "FKHelperTransportReadinessTests.h"
#import "FKHelperReadinessReportTests.h"
#import "FKHelperUnixSocketTransportTests.h"

@implementation FKTestRunner

+ (NSArray<NSString *> *)runAllChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSArray<Class> *suites = @[FKModelTests.class, FKBackupTests.class, FKJSONTests.class, FKOperationTests.class, FKHelperTrustTests.class, FKHelperIdentityTests.class, FKHelperMetadataTests.class, FKHelperManifestTests.class, FKHelperIntegrityTests.class, FKHelperProtocolTests.class, FKHelperTransportTests.class, FKHelperReportTests.class, FKHelperCapabilityTests.class, FKHelperGateTests.class, FKHelperDiscoveryTests.class, FKHelperPeerTests.class, FKHelperHandshakeTests.class, FKHelperRouterTests.class, FKHelperPluginTests.class, FKHelperConfigurationTests.class, FKHelperAuditTests.class, FKHelperBoundaryTests.class, FKHelperDeploymentTests.class, FKHelperAuthenticationTests.class, FKHelperReplayTests.class, FKHelperFrameTests.class, FKHelperTransportAssessmentTests.class, FKHelperKeyDerivationTests.class, FKHelperKeyLifecycleTests.class, FKHelperProtocolNegotiationTests.class, FKHelperHandshakeTranscriptTests.class, FKHelperKeyConfirmationTests.class, FKHelperHandshakeStateMachineTests.class, FKHelperPeerBindingTests.class, FKHelperSessionLifecycleTests.class, FKHelperAuthenticatedSessionTests.class, FKHelperTrustAnchorTests.class, FKHelperReleaseVerifierTests.class, FKHelperPeerCredentialTests.class, FKHelperTransportReadinessTests.class, FKHelperReadinessReportTests.class, FKHelperUnixSocketTransportTests.class];
    for (Class suite in suites) {
        NSArray *result = [suite runChecks];
        [failures addObjectsFromArray:result];
    }
    return failures.copy;
}

+ (NSDictionary *)runSummary {
    NSArray<Class> *classes = @[FKModelTests.class, FKBackupTests.class, FKJSONTests.class, FKOperationTests.class, FKHelperTrustTests.class, FKHelperIdentityTests.class, FKHelperMetadataTests.class, FKHelperManifestTests.class, FKHelperIntegrityTests.class, FKHelperProtocolTests.class, FKHelperTransportTests.class, FKHelperReportTests.class, FKHelperCapabilityTests.class, FKHelperGateTests.class, FKHelperDiscoveryTests.class, FKHelperPeerTests.class, FKHelperHandshakeTests.class, FKHelperRouterTests.class, FKHelperPluginTests.class, FKHelperConfigurationTests.class, FKHelperAuditTests.class, FKHelperBoundaryTests.class, FKHelperDeploymentTests.class, FKHelperAuthenticationTests.class, FKHelperReplayTests.class, FKHelperFrameTests.class, FKHelperTransportAssessmentTests.class, FKHelperKeyDerivationTests.class, FKHelperKeyLifecycleTests.class, FKHelperProtocolNegotiationTests.class, FKHelperHandshakeTranscriptTests.class, FKHelperKeyConfirmationTests.class, FKHelperHandshakeStateMachineTests.class, FKHelperPeerBindingTests.class, FKHelperSessionLifecycleTests.class, FKHelperAuthenticatedSessionTests.class, FKHelperTrustAnchorTests.class, FKHelperReleaseVerifierTests.class, FKHelperPeerCredentialTests.class, FKHelperTransportReadinessTests.class, FKHelperReadinessReportTests.class, FKHelperUnixSocketTransportTests.class];
    NSArray<NSString *> *names = @[@"model", @"backup", @"json", @"operation", @"trust", @"identity", @"metadata", @"manifest", @"integrity", @"protocol", @"transport", @"report", @"capability", @"gate", @"discovery", @"peer", @"handshake", @"router", @"plugin", @"configuration", @"audit", @"boundary", @"deployment", @"authentication", @"replay", @"frame", @"transport_assessment", @"key_derivation", @"key_lifecycle", @"protocol_negotiation", @"handshake_transcript", @"key_confirmation", @"handshake_state_machine", @"peer_binding", @"session_lifecycle", @"authenticated_session", @"trust_anchor", @"release_verifier", @"peer_credential", @"transport_readiness", @"readiness_report", @"unix_socket_transport"];
    NSMutableArray<NSDictionary *> *suiteJSON = [NSMutableArray array];
    NSUInteger total = 0, passed = 0, failed = 0;

    for (NSUInteger i = 0; i < classes.count; i++) {
        Class suite = classes[i];
        NSString *name = names[i];
        NSUInteger count = 0;
        NSArray<NSString *> *failures = @[];
        BOOL executed = YES;
        @try {
            count = [suite checkCount];
            failures = [suite runChecks] ?: @[];
        } @catch (NSException *exception) {
            // 单套件异常隔离：标记未正常执行，不影响其他套件汇总。
            executed = NO;
            failures = @[exception.reason.description];
        }
        NSUInteger suiteFailed = failures.count;
        NSUInteger suitePassed = executed ? (count > suiteFailed ? count - suiteFailed : 0) : 0;
        total += count;
        passed += suitePassed;
        failed += suiteFailed;
        [suiteJSON addObject:@{
            @"name": name,
            @"executed": @(executed),
            @"total": @(count),
            @"passed": @(suitePassed),
            @"failed": @(suiteFailed),
            @"skipped": @(0),
            @"failures": failures
        }];
    }

    NSString *status = (failed == 0 && total > 0) ? @"Passed" : (failed > 0 ? @"Failed" : @"NotTested");
    return @{
        @"executed": @YES,
        @"total": @(total),
        @"passed": @(passed),
        @"failed": @(failed),
        @"skipped": @(0),
        @"status": status,
        @"suites": suiteJSON.copy
    };
}

@end
