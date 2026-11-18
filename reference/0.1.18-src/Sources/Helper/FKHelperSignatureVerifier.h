#import <Foundation/Foundation.h>
#import "FKHelperTrust.h"

NS_ASSUME_NONNULL_BEGIN

/// Helper 签名验证：核对是否存在有效签名、签名主体与可信来源链。
/// 无可验证签名依据时返回 Unverified；已安装文件不等于可信。
@interface FKHelperSignatureVerifier : NSObject

/// 评估签名证据。reasons 追加说明；返回签名状态。
+ (FKSignatureStatus)verifySignatureWithPath:(NSString *)path reasons:(NSMutableArray<NSString *> *)reasons;

@end

NS_ASSUME_NONNULL_END
