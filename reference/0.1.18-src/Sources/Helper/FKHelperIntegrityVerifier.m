#import "FKHelperIntegrityVerifier.h"
#import "FKFileHasher.h"

@implementation FKHelperIntegrityResult

- (NSDictionary *)JSONDictionary {
    return @{
        @"status": @(self.status),
        @"calculatedSHA256": self.calculatedSHA256 ?: @"",
        @"expectedSHA256": self.expectedSHA256 ?: @"",
        @"reasonCode": self.reasonCode ?: @""
    };
}

@end

@implementation FKHelperIntegrityVerifier

+ (NSString *)localSHA256ForPath:(NSString *)path {
    if (path.length == 0) return nil;
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    return [FKFileHasher SHA256ForFileAtURL:url error:&error];
}

+ (FKHelperIntegrityStatus)verifyIntegrityWithPath:(NSString *)path
                                     trustedSHA256:(NSString *)trustedSHA256
                                            reasons:(NSMutableArray<NSString *> *)reasons {
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [reasons addObject:@"Helper 文件不存在，无法计算完整性摘要"];
        return FKHelperIntegrityUnavailable;
    }

    NSString *localDigest = [self localSHA256ForPath:path];
    if (localDigest.length == 0) {
        [reasons addObject:@"摘要计算失败，文件不可读或已损坏"];
        return FKHelperIntegrityUnavailable;
    }

    // 无可信发布锚点：只记录当前摘要，完整性状态保持 Unknown，不得判为通过。
    if (trustedSHA256.length == 0) {
        [reasons addObject:@"缺少可信发布清单摘要锚点，完整性暂不可视为已验证"];
        return FKHelperIntegrityUnknown;
    }

    if ([localDigest caseInsensitiveCompare:trustedSHA256] == NSOrderedSame) {
        return FKHelperIntegrityVerified;
    }

    [reasons addObject:@"本地摘要与可信发布记录不一致，文件可能被替换或损坏"];
    return FKHelperIntegrityMismatch;
}

- (FKHelperIntegrityResult *)verifyFileAtPath:(NSString *)path expectedSHA256:(nullable NSString *)expectedSHA256 {
    FKHelperIntegrityResult *result = [FKHelperIntegrityResult new];
    result.expectedSHA256 = expectedSHA256 ?: @"";

    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        result.status = FKHelperIntegrityUnavailable;
        result.reasonCode = @"file_missing";
        result.calculatedSHA256 = @"";
        return result;
    }

    NSString *localDigest = [FKHelperIntegrityVerifier localSHA256ForPath:path];
    if (localDigest.length == 0) {
        // 摘要计算失败：不得当作空摘要继续比对。
        result.status = FKHelperIntegrityUnavailable;
        result.reasonCode = @"digest_unavailable";
        result.calculatedSHA256 = @"";
        return result;
    }

    result.calculatedSHA256 = localDigest;

    if (expectedSHA256.length == 0) {
        result.status = FKHelperIntegrityUnknown;
        result.reasonCode = @"no_trusted_anchor";
        return result;
    }

    if ([localDigest caseInsensitiveCompare:expectedSHA256] == NSOrderedSame) {
        result.status = FKHelperIntegrityVerified;
        result.reasonCode = @"digest_match";
        return result;
    }

    result.status = FKHelperIntegrityMismatch;
    result.reasonCode = @"digest_mismatch";
    return result;
}

@end
