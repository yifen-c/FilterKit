#import "FKHelperDiscovery.h"
#import "FKHelperMetadata.h"

/// 已知普通系统工具基名（小写）。命中其一即按系统工具候选处理，不作为 FilterKit Helper 身份证据。
static NSSet<NSString *> *FKKnownSystemToolNames(void) {
    static dispatch_once_t onceToken;
    static NSSet<NSString *> *names;
    dispatch_once(&onceToken, ^{
        names = [NSSet setWithArray:@[
            @"path_helper", @"launchd", @"syslogd", @"configd", @"crashreporter",
            @"notifyd", @"usbd", @"prefetched", @"opendirectoryd", @"xpcproxy",
            @"installd", @"powerd", @"wifid", @"bluetoothd", @"tccd", @"securityd",
            @"mediaserverd", @"distnoted", @"cfprefsd", @"sudo", @"sh", @"bash"
        ]];
    });
    return names;
}

static BOOL FKIsSystemToolCandidate(FKHelperMetadata *metadata) {
    NSString *base = metadata.path.lastPathComponent.lowercaseString;
    if ([FKKnownSystemToolNames() containsObject:base]) return YES;
    // 无归属包且位于系统基础目录时，保守视为系统工具候选。
    if (metadata.packageIDs.count == 0) {
        NSArray<NSString *> *systemSegments = @[@"/usr/bin/", @"/usr/sbin/", @"/usr/libexec/", @"/System/"];
        for (NSString *segment in systemSegments) {
            if ([metadata.path containsString:segment]) return YES;
        }
    }
    return NO;
}

@implementation FKHelperDiscovery

+ (NSArray<FKHelperMetadata *> *)metadataForCandidates:(NSArray<NSDictionary *> *)candidates {
    NSMutableArray<FKHelperMetadata *> *result = [NSMutableArray array];
    if (![candidates isKindOfClass:NSArray.class]) return result.copy;
    for (NSDictionary *item in candidates) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        FKHelperMetadata *metadata = [FKHelperMetadata metadataFromCandidate:item];
        metadata.systemToolCandidate = FKIsSystemToolCandidate(metadata);
        [result addObject:metadata];
    }
    return result.copy;
}

+ (nullable FKHelperMetadata *)bestMetadataForCandidates:(NSArray<NSDictionary *> *)candidates {
    NSArray<FKHelperMetadata *> *all = [self metadataForCandidates:candidates];
    FKHelperMetadata *best = nil;
    NSInteger bestScore = -1;
    for (FKHelperMetadata *metadata in all) {
        if (!metadata.exists) continue;
        NSInteger score = 0;
        if (metadata.regularFile) score++;
        if (metadata.executable) score++;
        if (metadata.packageIDs.count > 0) score++;
        if (metadata.identifier.length > 0) score++;
        if (score > bestScore) {
            bestScore = score;
            best = metadata;
        }
    }
    return best;
}

+ (FKHelperDiscoveryStatus)statusForMetadata:(FKHelperMetadata *)metadata {
    if (!metadata || !metadata.exists) return FKHelperDiscoveryNotFound;
    if (!metadata.candidateSchemaValid || metadata.pathHasTraversal || !metadata.pathIsAbsolute) return FKHelperDiscoveryInvalid;
    if (!metadata.regularFile || ![metadata.fileType isEqualToString:@"regular"]) return FKHelperDiscoveryInvalid;
    if (!metadata.executable) return FKHelperDiscoveryIncomplete;
    if (FKIsSystemToolCandidate(metadata)) {
        metadata.systemToolCandidate = YES;
        return FKHelperDiscoveryIncomplete;
    }
    if (metadata.missingFields.count > 0) return FKHelperDiscoveryIncomplete;
    return FKHelperDiscoveryFound;
}

+ (NSString *)statusCodeForStatus:(FKHelperDiscoveryStatus)status {
    switch (status) {
        case FKHelperDiscoveryNotFound: return @"NOT_FOUND";
        case FKHelperDiscoveryFound: return @"FOUND";
        case FKHelperDiscoveryIncomplete: return @"INCOMPLETE";
        case FKHelperDiscoveryInvalid: return @"INVALID";
        case FKHelperDiscoveryVerified: return @"VERIFIED";
    }
    return @"UNKNOWN";
}

+ (NSString *)statusTextForStatus:(FKHelperDiscoveryStatus)status {
    switch (status) {
        case FKHelperDiscoveryNotFound: return @"未发现候选";
        case FKHelperDiscoveryFound: return @"已发现候选";
        case FKHelperDiscoveryIncomplete: return @"已发现候选 · 元数据不足";
        case FKHelperDiscoveryInvalid: return @"候选文件类型异常";
        case FKHelperDiscoveryVerified: return @"已验证";
    }
    return @"未知";
}

@end
