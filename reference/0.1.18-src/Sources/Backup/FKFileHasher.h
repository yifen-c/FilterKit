#import <Foundation/Foundation.h>

/// 文件哈希结果键：MD5 用于对照 dpkg .md5sums；SHA-256 用于备份前后内容一致性核对。
FOUNDATION_EXPORT NSString *const FKFileHashKeyMD5;
FOUNDATION_EXPORT NSString *const FKFileHashKeySHA256;

/// 流式文件哈希：分块读取，不把整个 dylib/资源文件一次性载入内存。
@interface FKFileHasher : NSObject

/// 计算文件 MD5（32 位十六进制）。仅服务软件包完整性诊断，不作为安全签名。
+ (NSString *)MD5ForFileAtURL:(NSURL *)url error:(NSError **)error;

/// 计算文件 SHA-256（十六进制）。用于备份内容完整性与恢复前一致性核对。
+ (NSString *)SHA256ForFileAtURL:(NSURL *)url error:(NSError **)error;

/// 一次流式读取同时计算 MD5 与 SHA-256，返回两个摘要；读取失败返回 nil 并填 error。
+ (NSDictionary<NSString *, NSString *> *)hashForFileAtURL:(NSURL *)url error:(NSError **)error;

@end
