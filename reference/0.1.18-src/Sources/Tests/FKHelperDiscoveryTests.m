#import "FKHelperDiscoveryTests.h"
#import "FKHelperServiceDiscovery.h"
#import "FKHelperServiceEndpoint.h"
#import "FKHelperConnectionStatus.h"
#import "FKHelperIdentity.h"

@implementation FKHelperDiscoveryTests

+ (NSUInteger)checkCount { return 16; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    NSString *expectedID = [FKHelperIdentity expectedIdentity].helperID;

    // SRV901：无候选 → NotFound，原因 binary_not_found。
    FKHelperServiceEndpoint *none = [FKHelperServiceDiscovery endpointForCandidate:nil];
    if (none.status != FKHelperDiscoveryNotFound) [failures addObject:@"SRV901 无候选应为 NotFound"];
    if (![none.reasonCode isEqualToString:@"binary_not_found"]) [failures addObject:@"SRV901 原因码应为 binary_not_found"];

    // SRV902：系统工具候选（path_helper）不得识别为 FilterKit Helper。
    NSDictionary *systemTool = @{@"path": @"/usr/bin/path_helper", @"exists": @(YES), @"regular_file": @(YES), @"executable": @(YES)};
    FKHelperServiceEndpoint *tool = [FKHelperServiceDiscovery endpointForCandidate:systemTool];
    if (tool.status != FKHelperDiscoveryIncomplete) [failures addObject:@"SRV902 系统工具候选应为 Incomplete"];
    if (![tool.reasonCode isEqualToString:@"system_tool_candidate"]) [failures addObject:@"SRV902 原因码应为 system_tool_candidate"];

    // SRV903：Helper ID 不匹配 → Invalid。
    NSDictionary *mismatch = @{@"path": @"/var/jbroot-abc/Helper/other", @"exists": @(YES), @"regular_file": @(YES),
                               @"executable": @(YES), @"version": @"1.0", @"helper_id": @"com.other.helper",
                               @"package_ids": @[@"com.other"]};
    FKHelperServiceEndpoint *mismatchEp = [FKHelperServiceDiscovery endpointForCandidate:mismatch];
    if (mismatchEp.status != FKHelperDiscoveryInvalid) [failures addObject:@"SRV903 标识不符应为 Invalid"];
    if (![mismatchEp.reasonCode isEqualToString:@"helper_id_mismatch"]) [failures addObject:@"SRV903 原因码应为 helper_id_mismatch"];

    // SRV904：必要元数据缺失 → Incomplete。
    NSDictionary *incomplete = @{@"path": @"/var/jbroot-abc/Helper/unknown", @"exists": @(YES), @"regular_file": @(YES), @"executable": @(YES)};
    FKHelperServiceEndpoint *incompleteEp = [FKHelperServiceDiscovery endpointForCandidate:incomplete];
    if (incompleteEp.status != FKHelperDiscoveryIncomplete) [failures addObject:@"SRV904 元数据缺失应为 Incomplete"];
    if (![incompleteEp.reasonCode isEqualToString:@"metadata_incomplete"]) [failures addObject:@"SRV904 原因码应为 metadata_incomplete"];

    // SRV905：形态完整且标识匹配仅记 Found，Discovery 不自行产生 Verified。
    NSDictionary *matched = @{@"path": @"/var/jbroot-abc/Helper/filterkit-helper", @"exists": @(YES), @"regular_file": @(YES),
                              @"executable": @(YES), @"version": @"0.1.18", @"helper_id": expectedID,
                              @"package_ids": @[expectedID], @"protocol_version": @(1)};
    FKHelperServiceEndpoint *matchedEp = [FKHelperServiceDiscovery endpointForCandidate:matched];
    if (matchedEp.status != FKHelperDiscoveryFound) [failures addObject:@"SRV905 形态完整应为 Found"];
    if (matchedEp.status == FKHelperDiscoveryVerified) [failures addObject:@"SRV905 Discovery 不得自行产生 Verified"];

    // SRV906：端点 JSON 含状态码 / 文案 / 来源。
    NSDictionary *json = matchedEp.JSONDictionary;
    if (!json[@"status"] || !json[@"statusText"] || !json[@"source"]) [failures addObject:@"SRV906 端点 JSON 字段不完整"];

    // SRV907：批量候选保持顺序。
    NSArray<FKHelperServiceEndpoint *> *batch = [FKHelperServiceDiscovery endpointsForCandidates:@[systemTool, mismatch, matched]];
    if (batch.count != 3) [failures addObject:@"SRV907 批量候选数量不符"];
    else if (batch[0].status != FKHelperDiscoveryIncomplete || batch[1].status != FKHelperDiscoveryInvalid || batch[2].status != FKHelperDiscoveryFound) {
        [failures addObject:@"SRV907 批量候选顺序或状态不符"];
    }

    // SRV908：连接就绪与终态判定。
    if (![FKHelperConnectionStatusCodec isReadOnlyReady:FKHelperConnectionReadyReadOnly]) [failures addObject:@"SRV908 ReadyReadOnly 应为就绪"];
    if ([FKHelperConnectionStatusCodec isReadOnlyReady:FKHelperConnectionDisconnected]) [failures addObject:@"SRV908 断开不应为就绪"];
    if (![FKHelperConnectionStatusCodec isTerminal:FKHelperConnectionDisconnected] ||
        ![FKHelperConnectionStatusCodec isTerminal:FKHelperConnectionTimeout] ||
        ![FKHelperConnectionStatusCodec isTerminal:FKHelperConnectionRejected]) {
        [failures addObject:@"SRV908 断开/超时/拒绝应为终态"];
    }

    // SRV909：相对路径不得成为有效 Helper 候选。
    NSDictionary *relativePath = @{@"path": @"private/var/helper", @"exists": @YES, @"regular_file": @YES,
                                   @"executable": @YES, @"version": @"0.1.18", @"helper_id": expectedID,
                                   @"package_ids": @[expectedID], @"protocol_version": @1};
    FKHelperServiceEndpoint *relativeEndpoint = [FKHelperServiceDiscovery endpointForCandidate:relativePath];
    if (relativeEndpoint.status != FKHelperDiscoveryInvalid || ![relativeEndpoint.reasonCode isEqualToString:@"path_not_absolute"]) {
        [failures addObject:@"SRV909 相对路径必须被拒绝"];
    }

    // SRV910：路径穿越不得被接受。
    NSMutableDictionary *traversal = [relativePath mutableCopy];
    traversal[@"path"] = @"/var/mobile/../Library/helper";
    FKHelperServiceEndpoint *traversalEndpoint = [FKHelperServiceDiscovery endpointForCandidate:traversal];
    if (traversalEndpoint.status != FKHelperDiscoveryInvalid || ![traversalEndpoint.reasonCode isEqualToString:@"path_contains_traversal"]) {
        [failures addObject:@"SRV910 路径穿越必须被拒绝"];
    }

    // SRV911：布尔字段类型错误不允许通过 boolValue 静默解释。
    NSMutableDictionary *badType = [matched mutableCopy];
    badType[@"exists"] = @"yes";
    FKHelperServiceEndpoint *badTypeEndpoint = [FKHelperServiceDiscovery endpointForCandidate:badType];
    if (badTypeEndpoint.status != FKHelperDiscoveryInvalid || ![badTypeEndpoint.reasonCode isEqualToString:@"exists_type_invalid"]) {
        [failures addObject:@"SRV911 元数据字段类型错误必须被拒绝"];
    }

    // SRV912：存在但不可执行的普通文件只能是 Incomplete。
    NSMutableDictionary *notExecutable = [matched mutableCopy];
    notExecutable[@"executable"] = @NO;
    FKHelperServiceEndpoint *notExecutableEndpoint = [FKHelperServiceDiscovery endpointForCandidate:notExecutable];
    if (notExecutableEndpoint.status != FKHelperDiscoveryIncomplete || ![notExecutableEndpoint.reasonCode isEqualToString:@"not_executable"]) {
        [failures addObject:@"SRV912 不可执行候选必须降级"];
    }

    // SRV913：发现报告必须保留逐项证据，并显式禁止把 Found 当成可信或 IPC 就绪。
    NSDictionary *report = [FKHelperServiceDiscovery discoveryReportForCandidates:@[matched, mismatch, relativePath]];
    if ([report[@"candidateCount"] unsignedIntegerValue] != 3 ||
        [report[@"foundCount"] unsignedIntegerValue] != 1 ||
        ![report[@"trustStatus"] isEqualToString:@"unknown"] ||
        [report[@"realIPCReady"] boolValue] || [report[@"writeOperationsAllowed"] boolValue] ||
        ![report[@"selectedCandidatePath"] isEqualToString:matched[@"path"]]) {
        [failures addObject:@"SRV913 发现报告计数或安全边界错误"];
    }
    NSArray *records = report[@"candidates"];
    if (records.count != 3 || ![records.firstObject[@"metadata"] isKindOfClass:NSDictionary.class]) {
        [failures addObject:@"SRV913 发现报告缺少逐候选元数据"];
    }

    // SRV914：非字典候选不能导致批量发现崩溃，且不能被提升为 Found。
    NSArray<FKHelperServiceEndpoint *> *mixed = [FKHelperServiceDiscovery endpointsForCandidates:(NSArray *)@[matched, @"invalid"]];
    if (mixed.count != 2 || mixed[1].status == FKHelperDiscoveryFound || mixed[1].status == FKHelperDiscoveryVerified) {
        [failures addObject:@"SRV914 非字典候选必须安全降级"];
    }

    // SRV915：路径有效但文件不存在时应为 NotFound，而不是误报文件类型异常。
    NSMutableDictionary *absent = [matched mutableCopy];
    absent[@"exists"] = @NO;
    FKHelperServiceEndpoint *absentEndpoint = [FKHelperServiceDiscovery endpointForCandidate:absent];
    if (absentEndpoint.status != FKHelperDiscoveryNotFound || ![absentEndpoint.reasonCode isEqualToString:@"binary_not_found"]) {
        [failures addObject:@"SRV915 不存在的候选应返回 NotFound"];
    }

    // SRV916：符号链接不得伪装成 Helper 普通可执行文件。
    NSMutableDictionary *symlink = [matched mutableCopy];
    symlink[@"regular_file"] = @NO;
    symlink[@"executable"] = @NO;
    symlink[@"file_type"] = @"symlink";
    FKHelperServiceEndpoint *symlinkEndpoint = [FKHelperServiceDiscovery endpointForCandidate:symlink];
    if (symlinkEndpoint.status != FKHelperDiscoveryInvalid || ![symlinkEndpoint.reasonCode isEqualToString:@"file_type_not_regular"]) {
        [failures addObject:@"SRV916 符号链接不得作为普通 Helper 文件"];
    }

    return failures.copy;
}

@end
