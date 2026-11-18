#import "FKFileHasher.h"
#import <CommonCrypto/CommonDigest.h>

NSString *const FKFileHashKeyMD5 = @"md5";
NSString *const FKFileHashKeySHA256 = @"sha256";

/// 读取分块大小：64KB，避免大文件整体驻留内存。
static const size_t FKHashChunkSize = 64 * 1024;

static NSString *FKHexDigest(const unsigned char *digest, CC_LONG length) {
    NSMutableString *hex = [NSMutableString stringWithCapacity:length * 2];
    for (CC_LONG i = 0; i < length; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex.copy;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// MD5 仅用于对照 dpkg .md5sums 的既有格式，不能替换为 SHA-256；此处局部抑制 deprecated 告警。
static BOOL FKStreamHash(NSURL *url, NSString **outMD5, NSString **outSHA256, NSError **error) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:url.path];
    if (!handle) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoPermissionError
                                     userInfo:@{NSLocalizedDescriptionKey: @"文件不存在或不可读取"}];
        }
        return NO;
    }

    CC_MD5_CTX md5Ctx;
    CC_MD5_Init(&md5Ctx);
    CC_SHA256_CTX sha256Ctx;
    CC_SHA256_Init(&sha256Ctx);

    BOOL ok = YES;
    @try {
        while (YES) {
            NSData *chunk = [handle readDataOfLength:FKHashChunkSize];
            if (chunk.length == 0) break;
            CC_MD5_Update(&md5Ctx, chunk.bytes, (CC_LONG)chunk.length);
            CC_SHA256_Update(&sha256Ctx, chunk.bytes, (CC_LONG)chunk.length);
        }
    } @catch (NSException *exception) {
        ok = NO;
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"读取文件失败"}];
        }
    } @finally {
        [handle closeFile];
    }

    if (!ok) return NO;

    unsigned char md5Digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(md5Digest, &md5Ctx);
    unsigned char sha256Digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(sha256Digest, &sha256Ctx);

    if (outMD5) *outMD5 = FKHexDigest(md5Digest, CC_MD5_DIGEST_LENGTH);
    if (outSHA256) *outSHA256 = FKHexDigest(sha256Digest, CC_SHA256_DIGEST_LENGTH);
    return YES;
}
#pragma clang diagnostic pop

@implementation FKFileHasher

+ (NSString *)MD5ForFileAtURL:(NSURL *)url error:(NSError **)error {
    NSString *md5 = nil;
    return FKStreamHash(url, &md5, NULL, error) ? md5 : nil;
}

+ (NSString *)SHA256ForFileAtURL:(NSURL *)url error:(NSError **)error {
    NSString *sha256 = nil;
    return FKStreamHash(url, NULL, &sha256, error) ? sha256 : nil;
}

+ (NSDictionary<NSString *, NSString *> *)hashForFileAtURL:(NSURL *)url error:(NSError **)error {
    NSString *md5 = nil;
    NSString *sha256 = nil;
    if (!FKStreamHash(url, &md5, &sha256, error)) return nil;
    return @{FKFileHashKeyMD5: md5 ?: @"", FKFileHashKeySHA256: sha256 ?: @""};
}

@end
