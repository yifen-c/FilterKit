#import "FKHelperManifestVerifier.h"

NSErrorDomain const FKHelperManifestErrorDomain = @"com.filterkit.helper.manifest";

@implementation FKHelperManifestVerificationResult

+ (instancetype)resultWithStatus:(FKHelperManifestStatus)status
                           reason:(NSString *)reasonCode
                      description:(NSString *)description
                            error:(FKHelperManifestErrorCode)errorCode
                        manifestKeyID:(nullable NSString *)keyID {
    FKHelperManifestVerificationResult *result = [FKHelperManifestVerificationResult new];
    result.status = status;
    result.reasonCode = reasonCode;
    result.reasonDescription = description;
    result.errorCode = errorCode;
    result.manifestKeyID = keyID;
    return result;
}

- (BOOL)allowsTrustedRelease {
    return self.status == FKHelperManifestStatusVerified;
}

@end

@implementation FKHelperManifestVerifier

+ (FKHelperManifestVerificationResult *)invalidResultWithReason:(NSString *)reasonCode
                                                    description:(NSString *)description
                                                          error:(FKHelperManifestErrorCode)errorCode {
    return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusInvalid
                                                         reason:reasonCode
                                                    description:description
                                                          error:errorCode
                                                      manifestKeyID:nil];
}

+ (FKHelperManifestVerificationResult *)verifyManifest:(nullable FKHelperTrustManifest *)manifest
                                             signature:(nullable NSData *)signature
                                      expectedHelperID:(NSString *)expectedHelperID {
    // 1. 清单缺失。
    if (manifest == nil) {
        return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusUnavailable
                                                             reason:@"manifest_missing"
                                                        description:@"未读取到 Helper 发布清单"
                                                              error:FKHelperManifestErrorMissing
                                                          manifestKeyID:nil];
    }

    // 2. 结构非法。
    if (![manifest isStructurallyValid]) {
        return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusInvalid
                                                             reason:@"manifest_invalid"
                                                        description:@"发布清单必要字段缺失或协议版本非法"
                                                              error:FKHelperManifestErrorInvalidStructure
                                                          manifestKeyID:manifest.manifestKeyID];
    }

    // 3. 身份不匹配。
    if (expectedHelperID.length > 0 && ![manifest.helperID isEqualToString:expectedHelperID]) {
        return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusInvalid
                                                             reason:@"identity_mismatch"
                                                        description:@"清单 Helper ID 与预期身份不一致"
                                                              error:FKHelperManifestErrorIdentityMismatch
                                                          manifestKeyID:manifest.manifestKeyID];
    }

    // 4. 已登记摘要格式非法。
    for (FKHelperArtifact *artifact in manifest.artifacts) {
        if (artifact.sha256.length > 0 &&
            ![FKHelperTrustManifest isValidSHA256Hex:artifact.sha256]) {
            return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusInvalid
                                                                 reason:@"digest_invalid"
                                                            description:@"清单登记的摘要格式非法"
                                                                  error:FKHelperManifestErrorInvalidDigest
                                                              manifestKeyID:manifest.manifestKeyID];
        }
    }

    // 5. 无清单签名数据：无可信锚点，保持 Unknown。
    if (signature == nil || signature.length == 0) {
        return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusUnknown
                                                             reason:@"manifest_unsigned"
                                                        description:@"清单缺少签名，无可信发布锚点"
                                                              error:FKHelperManifestErrorUnsigned
                                                          manifestKeyID:manifest.manifestKeyID];
    }

    // 6. Key ID 未知：无法识别签发公钥，保持 Unknown。
    if (manifest.manifestKeyID.length == 0) {
        return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusUnknown
                                                             reason:@"unknown_key_id"
                                                        description:@"清单签发公钥 Key ID 未知"
                                                              error:FKHelperManifestErrorUnknownKey
                                                          manifestKeyID:nil];
    }

    // 7. 开发通道不得冒充正式发布。
    if (manifest.isDevelopmentRelease) {
        return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusUnknown
                                                             reason:@"development_channel"
                                                        description:@"当前为开发通道清单，不得按正式发布版本放行"
                                                              error:FKHelperManifestErrorDevelopmentChannel
                                                          manifestKeyID:manifest.manifestKeyID];
    }

    // 8. 0.1.15 未内置可信公钥，即便以上齐备也不产生 Verified 结论。
    return [FKHelperManifestVerificationResult resultWithStatus:FKHelperManifestStatusUnknown
                                                         reason:@"no_trusted_anchor"
                                                    description:@"尚未建立内置可信发布锚点，清单未经验签"
                                                          error:FKHelperManifestErrorUnsigned
                                                      manifestKeyID:manifest.manifestKeyID];
}

#pragma mark - FKHelperManifestVerifying

- (BOOL)verifyManifestData:(NSData *)manifestData
                  signature:(nullable NSData *)signature
                      error:(NSError * _Nullable * _Nullable)error {
    // 0.1.15 默认实现不执行密码学验签；验证能力由后续可信发布流程接入的替换实现提供。
    if (error != NULL) {
        *error = [NSError errorWithDomain:FKHelperManifestErrorDomain
                                      code:FKHelperManifestErrorMissing
                                  userInfo:@{NSLocalizedDescriptionKey: @"清单签名验证器尚未配置可信锚点"}];
    }
    return NO;
}

@end
