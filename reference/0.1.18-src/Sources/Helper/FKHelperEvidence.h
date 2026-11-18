#import <Foundation/Foundation.h>

/// Helper 身份与签名证据集合。摘要只用于记录文件身份与变化，不证明发布者身份；
/// 无可信锚点（官方签名链 / 可信公钥 / 确认包来源）时不得判为可信。
@interface FKHelperEvidence : NSObject

/// 候选可执行路径
@property (nonatomic, copy) NSString *path;
/// 文件类型（regular / directory / symlink / unknown）
@property (nonatomic, copy) NSString *fileType;
/// 归属软件包标识
@property (nonatomic, copy) NSString *packageID;
/// 包来源（official_repo / trusted_repo / manual / unknown）
@property (nonatomic, copy) NSString *packageSource;
/// 版本信息
@property (nonatomic, copy) NSString *version;
/// 是否具备可执行权限
@property (nonatomic, assign) BOOL executable;
/// 文件摘要（MD5 / SHA-256，仅记录身份与变化）
@property (nonatomic, copy) NSString *fileDigest;
/// 代码签名描述（未接入 SecStaticCode 时为未取得）
@property (nonatomic, copy) NSString *codeSignature;
/// 签名主体；无可验证主体为空
@property (nonatomic, copy) NSString *signerSubject;
/// 信任链来源（official_chain / trusted_public_key / confirmed_package / none）
@property (nonatomic, copy) NSString *trustChainSource;
/// 证据采集时间
@property (nonatomic, copy) NSDate *checkedAt;

- (NSDictionary *)JSONDictionary;

@end
