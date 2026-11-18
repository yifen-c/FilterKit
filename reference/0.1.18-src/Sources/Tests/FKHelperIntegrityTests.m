#import "FKHelperIntegrityTests.h"
#import "FKHelperIntegrityVerifier.h"
#import "FKFileHasher.h"

@implementation FKHelperIntegrityTests

+ (NSUInteger)checkCount { return 9; }

+ (NSString *)tempPathWithTag:(NSString *)tag {
    NSString *name = [NSString stringWithFormat:@"fk-int-test-%@.dat", tag];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

+ (NSString *)writeTempData:(NSData *)data tag:(NSString *)tag {
    NSString *path = [self tempPathWithTag:tag];
    [data writeToFile:path atomically:YES];
    return path;
}

+ (BOOL)isSHA256Hex:(NSString *)value {
    if (value.length != 64) return NO;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    return [value rangeOfCharacterFromSet:hex.invertedSet].location == NSNotFound;
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSMutableArray<NSString *> *createdPaths = [NSMutableArray array];
    FKHelperIntegrityVerifier *verifier = [FKHelperIntegrityVerifier new];

    @try {
        // INT801：普通文件 SHA-256 正确且与 FileHasher 复核一致。
        NSData *sample = [@"filterkit-018" dataUsingEncoding:NSUTF8StringEncoding];
        NSString *samplePath = [self writeTempData:sample tag:@"sample"];
        [createdPaths addObject:samplePath];
        NSString *localDigest = [FKHelperIntegrityVerifier localSHA256ForPath:samplePath];
        NSURL *sampleURL = [NSURL fileURLWithPath:samplePath];
        NSString *hasherDigest = [FKFileHasher SHA256ForFileAtURL:sampleURL error:nil];
        if (![self isSHA256Hex:localDigest] || ![localDigest isEqualToString:hasherDigest]) {
            [failures addObject:@"INT801 普通文件 SHA-256 计算或复核不一致"];
        }

        // INT802：大文件（1 MiB）走流式计算，不崩溃且产出合法摘要。
        NSMutableData *big = [NSMutableData dataWithLength:1024 * 1024];
        NSString *bigPath = [self writeTempData:big tag:@"big"];
        [createdPaths addObject:bigPath];
        NSString *bigDigest = [FKHelperIntegrityVerifier localSHA256ForPath:bigPath];
        if (![self isSHA256Hex:bigDigest]) {
            [failures addObject:@"INT802 大文件流式 SHA-256 结果非法"];
        }

        // INT803：空文件摘要正确（空串 SHA-256）。
        NSString *emptyPath = [self writeTempData:[NSData data] tag:@"empty"];
        [createdPaths addObject:emptyPath];
        NSString *emptyDigest = [FKHelperIntegrityVerifier localSHA256ForPath:emptyPath];
        if (![emptyDigest isEqualToString:@"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"]) {
            [failures addObject:@"INT803 空文件 SHA-256 不正确"];
        }

        // INT804：不可读 / 不存在路径返回 Unavailable。
        FKHelperIntegrityResult *missing = [verifier verifyFileAtPath:@"/var/jb/nonexistent/fk-helper.bin" expectedSHA256:nil];
        if (missing.status != FKHelperIntegrityUnavailable || ![missing.reasonCode isEqualToString:@"file_missing"]) {
            [failures addObject:@"INT804 不存在文件应返回 Unavailable"];
        }

        // INT805：无可信摘要锚点保持 Unknown。
        FKHelperIntegrityResult *noAnchor = [verifier verifyFileAtPath:samplePath expectedSHA256:nil];
        if (noAnchor.status != FKHelperIntegrityUnknown || ![noAnchor.reasonCode isEqualToString:@"no_trusted_anchor"]) {
            [failures addObject:@"INT805 无可信摘要应保持 Unknown"];
        }

        // INT806：摘要不匹配返回 Mismatch。
        NSString *zeroDigest = [@"" stringByPaddingToLength:64 withString:@"0" startingAtIndex:0];
        FKHelperIntegrityResult *mismatch = [verifier verifyFileAtPath:samplePath expectedSHA256:zeroDigest];
        if (mismatch.status != FKHelperIntegrityMismatch || ![mismatch.reasonCode isEqualToString:@"digest_mismatch"]) {
            [failures addObject:@"INT806 摘要不匹配应返回 Mismatch"];
        }

        // INT807：与可信发布记录摘要匹配才允许 Verified。
        FKHelperIntegrityResult *matched = [verifier verifyFileAtPath:samplePath expectedSHA256:localDigest];
        if (matched.status != FKHelperIntegrityVerified || ![matched.reasonCode isEqualToString:@"digest_match"]) {
            [failures addObject:@"INT807 摘要匹配可信记录应返回 Verified"];
        }

        // INT808：文件变化后重新计算，摘要应随之变化。
        NSString *digestA = [FKHelperIntegrityVerifier localSHA256ForPath:samplePath];
        NSData *changed = [@"filterkit-changed-content" dataUsingEncoding:NSUTF8StringEncoding];
        [changed writeToFile:samplePath atomically:YES];
        NSString *digestB = [FKHelperIntegrityVerifier localSHA256ForPath:samplePath];
        if ([digestA isEqualToString:digestB]) {
            [failures addObject:@"INT808 文件变更后摘要未重新计算"];
        }

        // INT809：完整性结果不携带签名状态，二者分开显示。
        NSDictionary *resultJSON = matched.JSONDictionary;
        if (resultJSON[@"signatureStatus"] != nil || resultJSON[@"signature"] != nil) {
            [failures addObject:@"INT809 完整性结果不应混入签名状态字段"];
        }
    } @finally {
        for (NSString *createdPath in createdPaths) {
            [[NSFileManager defaultManager] removeItemAtPath:createdPath error:nil];
        }
    }

    return failures.copy;
}

@end
