#import <Foundation/Foundation.h>
#import "FKHelperTrustManifest.h"

NS_ASSUME_NONNULL_BEGIN

/// 清单验证错误域。
extern NSErrorDomain const FKHelperManifestErrorDomain;

/// 清单验证错误码；每一类失败都对应明确原因码，业务层不得假定验证成功。
typedef NS_ENUM(NSInteger, FKHelperManifestErrorCode) {
    FKHelperManifestErrorNone = 0,
    FKHelperManifestErrorMissing,
    FKHelperManifestErrorInvalidStructure,
    FKHelperManifestErrorIdentityMismatch,
    FKHelperManifestErrorInvalidDigest,
    FKHelperManifestErrorUnsigned,
    FKHelperManifestErrorUnknownKey,
    FKHelperManifestErrorSignatureInvalid,
    FKHelperManifestErrorDevelopmentChannel
};

/// 清单签名验证结果。0.1.15 未内置可信公钥与正式签名产物，默认实现不产生 Verified 结论。
@interface FKHelperManifestVerificationResult : NSObject

/// 验证状态。
@property (nonatomic, assign) FKHelperManifestStatus status;
/// 识别到的清单公钥 Key ID（可能为空）。
@property (nonatomic, copy, nullable) NSString *manifestKeyID;
/// 机器可读原因码。
@property (nonatomic, copy) NSString *reasonCode;
/// 可读原因描述。
@property (nonatomic, copy) NSString *reasonDescription;
/// 错误码。
@property (nonatomic, assign) FKHelperManifestErrorCode errorCode;

/// 是否允许据此放行（仅 Verified 为 YES）。
@property (nonatomic, readonly) BOOL allowsTrustedRelease;

+ (instancetype)resultWithStatus:(FKHelperManifestStatus)status
                           reason:(NSString *)reasonCode
                      description:(NSString *)description
                            error:(FKHelperManifestErrorCode)errorCode
                        manifestKeyID:(nullable NSString *)keyID;

@end

/// 可替换的清单签名验证接口。具体密码学实现依据当前 iOS SDK 与构建环境确认；
/// 业务层只依赖该协议，不假定某一固定传输或签名方案。
@protocol FKHelperManifestVerifying <NSObject>

/// 校验清单数据与其签名。返回 NO 时 error 携带明确原因；不得把未验证视为通过。
- (BOOL)verifyManifestData:(NSData *)manifestData
                  signature:(nullable NSData *)signature
                      error:(NSError * _Nullable * _Nullable)error;

@end

/// 默认清单验证器：0.1.15 不执行密码学验签，仅按结构、身份、摘要格式、签名存在性、
/// Key ID 与发布通道给出保守结论（Unknown / Invalid / Unavailable）。
/// Verified 结论须等待内置可信公钥、正式签名清单与摘要比对独立验收后由替换实现给出。
@interface FKHelperManifestVerifier : NSObject <FKHelperManifestVerifying>

/// 评估清单与预期 Helper 身份。signature 为清单签名数据；0.1.15 无可信锚点，默认不放行。
+ (FKHelperManifestVerificationResult *)verifyManifest:(nullable FKHelperTrustManifest *)manifest
                                             signature:(nullable NSData *)signature
                                      expectedHelperID:(NSString *)expectedHelperID;

/// 构造一个 Invalid 结论（供签名损坏等拒绝路径使用）。
+ (FKHelperManifestVerificationResult *)invalidResultWithReason:(NSString *)reasonCode
                                                    description:(NSString *)description
                                                          error:(FKHelperManifestErrorCode)errorCode;

@end

NS_ASSUME_NONNULL_END
