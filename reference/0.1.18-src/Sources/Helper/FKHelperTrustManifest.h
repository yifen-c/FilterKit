#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 清单产物条目：记录某架构 Helper 二进制的可信摘要与签名身份。
/// 摘要只用于比对，不提供来源认证；在官方签名链建立之前不得据此判为可信。
@interface FKHelperArtifact : NSObject <NSSecureCoding>

/// 架构（arm64 / arm64e）。
@property (nonatomic, copy) NSString *architecture;
/// 可信 SHA256（64 位十六进制）；为空表示未登记可信摘要。
@property (nonatomic, copy) NSString *sha256;
/// 签名身份；无可验证主体为空。
@property (nonatomic, copy) NSString *signatureIdentity;

- (NSDictionary *)JSONDictionary;
+ (nullable instancetype)artifactFromDictionary:(nullable NSDictionary *)dictionary;

@end

/// 可信发布清单验证状态。只有经过独立签名链与摘要比对全部通过才允许 Verified；
/// 结构非法为 Invalid，缺少可信锚点为 Unknown，清单不可用为 Unavailable。
typedef NS_ENUM(NSInteger, FKHelperManifestStatus) {
    FKHelperManifestStatusUnknown = 0,
    FKHelperManifestStatusVerified,
    FKHelperManifestStatusInvalid,
    FKHelperManifestStatusUnavailable
};

/// 可信发布清单结构。
///
/// Manifest 不能自证可信：清单签名必须由内置可信发布公钥独立验证，
/// Helper 二进制摘要再与清单记录比对；首次扫描不得把本地计算摘要自动存为可信锚点，
/// 也不能从未经验证的 Helper 中读取它自己的可信锚点。
@interface FKHelperTrustManifest : NSObject <NSSecureCoding>

/// 清单结构版本。
@property (nonatomic, assign) NSInteger schemaVersion;
/// Helper 稳定标识。
@property (nonatomic, copy) NSString *helperID;
/// 产品标识。
@property (nonatomic, copy) NSString *productID;
/// 组件标识。
@property (nonatomic, copy) NSString *componentID;
/// 版本号。
@property (nonatomic, copy) NSString *version;
/// 构建 ID。
@property (nonatomic, copy) NSString *buildID;
/// 协议主版本。
@property (nonatomic, assign) NSInteger protocolMajor;
/// 协议次版本。
@property (nonatomic, assign) NSInteger protocolMinor;
/// 产物条目集合。
@property (nonatomic, copy) NSArray<FKHelperArtifact *> *artifacts;
/// 签发清单的可信公钥 Key ID；未知或为空表示无可识别锚点。
@property (nonatomic, copy, nullable) NSString *manifestKeyID;
/// 发布通道状态（development / release）。
@property (nonatomic, copy) NSString *releaseStatus;

/// 结构完整性：必要字段齐备且协议主版本 >= 1。
- (BOOL)isStructurallyValid;

/// 是否登记了非空且格式合法的可信摘要条目；空摘要清单不得用于完整性放行。
- (BOOL)hasTrustedArtifacts;

/// 是否为开发通道（非 release 即视为开发版，不得冒充正式发布）。
- (BOOL)isDevelopmentRelease;

/// 按架构取产物条目；无匹配返回 nil。
- (nullable FKHelperArtifact *)artifactForArchitecture:(NSString *)architecture;

- (NSDictionary *)JSONDictionary;
+ (nullable instancetype)manifestFromDictionary:(nullable NSDictionary *)dictionary;

/// 摘要格式校验：64 位十六进制；空值或非法格式返回 NO。
+ (BOOL)isValidSHA256Hex:(nullable NSString *)value;

@end

NS_ASSUME_NONNULL_END
