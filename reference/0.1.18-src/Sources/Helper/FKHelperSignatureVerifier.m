#import "FKHelperSignatureVerifier.h"

@implementation FKHelperSignatureVerifier

+ (FKSignatureStatus)verifySignatureWithPath:(NSString *)path reasons:(NSMutableArray<NSString *> *)reasons {
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [reasons addObject:@"Helper 文件不存在，无法校验签名"];
        return FKSignatureStatusUnknown;
    }
    // 预留：后续在确认 SDK 可用后接入 SecStaticCode / SecCodeCheckValidity，校验签名主体、
    // 证书链与强制签名要求。当前构建未提供可用签名校验手段，按 Unsupported 处理：
    // 不臆断 Valid，也不把“未取得签名证据”当作签名无效。
    [reasons addObject:@"当前未接入可用签名校验 API，签名主体与来源链无法确认"];
    return FKSignatureStatusUnsupported;
}

@end
