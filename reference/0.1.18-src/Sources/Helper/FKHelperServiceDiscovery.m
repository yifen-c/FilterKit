#import "FKHelperServiceDiscovery.h"
#import "FKHelperMetadata.h"
#import "FKHelperIdentity.h"

@implementation FKHelperServiceDiscovery

+ (FKHelperServiceEndpoint *)endpointForCandidate:(nullable NSDictionary *)candidate {
    if (![candidate isKindOfClass:NSDictionary.class] || candidate.count == 0) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:@""
                                                            helperID:nil
                                                              status:FKHelperDiscoveryNotFound
                                                              source:@"unknown"
                                                          reasonCode:@"binary_not_found"];
    }

    NSArray<FKHelperMetadata *> *all = [FKHelperDiscovery metadataForCandidates:@[candidate]];
    FKHelperMetadata *meta = all.firstObject;
    if (!meta) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:@""
                                                            helperID:nil
                                                              status:FKHelperDiscoveryNotFound
                                                              source:@"unknown"
                                                          reasonCode:@"binary_not_found"];
    }
    id serviceNameValue = candidate[@"serviceName"];
    NSString *serviceName = meta.path.length ? meta.path : ([serviceNameValue isKindOfClass:NSString.class] ? serviceNameValue : @"");
    NSString *expectedID = [FKHelperIdentity expectedIdentity].helperID;

    // 结构异常、路径不安全或候选字段类型错误时，不允许进入正常候选流程。
    if (!meta.candidateSchemaValid || !meta.pathIsAbsolute || meta.pathHasTraversal) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:serviceName
                                                            helperID:meta.identifier
                                                              status:FKHelperDiscoveryInvalid
                                                              source:@"filesystem_metadata"
                                                          reasonCode:meta.validationIssues.firstObject ?: @"invalid_candidate_metadata"];
    }

    if (!meta.exists) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:serviceName helperID:meta.identifier status:FKHelperDiscoveryNotFound source:@"filesystem_metadata" reasonCode:@"binary_not_found"];
    }

    // 系统工具候选（如 path_helper）不得识别为 FilterKit Helper。
    if (meta.systemToolCandidate) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:serviceName
                                                            helperID:meta.identifier
                                                              status:FKHelperDiscoveryIncomplete
                                                              source:@"system_tool"
                                                          reasonCode:@"system_tool_candidate"];
    }

    // 自报标识与预期 Helper 标识不符：标识不符，不纳入可信候选。
    if (meta.identifier.length > 0 && ![meta.identifier isEqualToString:expectedID]) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:serviceName
                                                            helperID:meta.identifier
                                                              status:FKHelperDiscoveryInvalid
                                                              source:@"filesystem_metadata"
                                                          reasonCode:@"helper_id_mismatch"];
    }

    // 非常规文件或不可执行候选不得视为有效 Helper。
    if (!meta.regularFile || ![meta.fileType isEqualToString:@"regular"]) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:serviceName helperID:meta.identifier status:FKHelperDiscoveryInvalid source:@"filesystem_metadata" reasonCode:@"not_regular_file"];
    }
    if (!meta.executable) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:serviceName helperID:meta.identifier status:FKHelperDiscoveryIncomplete source:@"filesystem_metadata" reasonCode:@"not_executable"];
    }

    // 必要元数据缺失：证据不足，保持 Incomplete。
    if (meta.missingFields.count > 0 || meta.identifier.length == 0) {
        return [[FKHelperServiceEndpoint alloc] initWithServiceName:serviceName
                                                            helperID:meta.identifier
                                                              status:FKHelperDiscoveryIncomplete
                                                              source:@"filesystem_metadata"
                                                          reasonCode:@"metadata_incomplete"];
    }

    // 形态完整且标识匹配：仅记为 Found；Verified 只能由后续信任验证流程产生。
    return [[FKHelperServiceEndpoint alloc] initWithServiceName:serviceName
                                                        helperID:meta.identifier
                                                          status:FKHelperDiscoveryFound
                                                          source:@"filesystem_metadata"
                                                      reasonCode:nil];
}

+ (NSArray<FKHelperServiceEndpoint *> *)endpointsForCandidates:(NSArray<NSDictionary *> *)candidates {
    NSMutableArray<FKHelperServiceEndpoint *> *endpoints = [NSMutableArray array];
    if (![candidates isKindOfClass:NSArray.class]) return endpoints.copy;
    for (id candidate in candidates) {
        [endpoints addObject:[self endpointForCandidate:[candidate isKindOfClass:NSDictionary.class] ? candidate : nil]];
    }
    return endpoints.copy;
}

+ (NSDictionary *)discoveryReportForCandidates:(NSArray<NSDictionary *> *)candidates {
    NSArray<NSDictionary *> *safeCandidates = [candidates isKindOfClass:NSArray.class] ? candidates : @[];
    NSArray<FKHelperServiceEndpoint *> *endpoints = [self endpointsForCandidates:safeCandidates];
    NSMutableArray<NSDictionary *> *records = [NSMutableArray arrayWithCapacity:endpoints.count];
    NSUInteger found = 0, incomplete = 0, invalid = 0, notFound = 0;
    NSString *selectedPath = @"";
    NSString *expectedID = [FKHelperIdentity expectedIdentity].helperID;

    for (NSUInteger index = 0; index < endpoints.count; index++) {
        FKHelperServiceEndpoint *endpoint = endpoints[index];
        NSDictionary *candidate = [safeCandidates[index] isKindOfClass:NSDictionary.class] ? safeCandidates[index] : @{};
        FKHelperMetadata *metadata = [FKHelperMetadata metadataFromCandidate:candidate];
        metadata.systemToolCandidate = [endpoint.source isEqualToString:@"system_tool"];
        [records addObject:@{@"endpoint": endpoint.JSONDictionary, @"metadata": metadata.JSONDictionary}];
        switch (endpoint.status) {
            case FKHelperDiscoveryFound:
                found++;
                if (selectedPath.length == 0 && [endpoint.helperID isEqualToString:expectedID]) selectedPath = endpoint.serviceName;
                break;
            case FKHelperDiscoveryIncomplete: incomplete++; break;
            case FKHelperDiscoveryInvalid: invalid++; break;
            case FKHelperDiscoveryNotFound: notFound++; break;
            case FKHelperDiscoveryVerified: break; // Discovery 永远不生成 Verified。
        }
    }

    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    return @{
        @"schemaVersion": @1,
        @"generatedAt": [formatter stringFromDate:[NSDate date]],
        @"candidateCount": @(endpoints.count),
        @"foundCount": @(found),
        @"incompleteCount": @(incomplete),
        @"invalidCount": @(invalid),
        @"notFoundCount": @(notFound),
        @"selectedCandidatePath": selectedPath,
        @"candidates": records.copy,
        @"trustStatus": @"unknown",
        @"realIPCReady": @NO,
        @"writeOperationsAllowed": @NO,
        @"nextStep": found > 0 ? @"verify_manifest_signature_and_peer_identity" : @"helper_artifact_unavailable"
    };
}

@end
