#import <Foundation/Foundation.h>

/// Helper 可信来源策略。可信锚点仅限三类：官方可验证签名链、已确认发行者公钥、
/// 经过确认的软件包来源；文件名、路径或普通摘要不足以建立身份信任。
/// 策略带版本管理，一次扫描得到的摘要不永久作为可信凭据。
@interface FKHelperTrustStore : NSObject

/// 策略版本号；调整可信锚点规则时应递增。
@property (nonatomic, copy, readonly) NSString *policyVersion;

/// 指定包是否存在可用的可信锚点。本期未配置官方链 / 公钥 / 确认来源，恒为 NO。
- (BOOL)hasTrustedAnchorForPackageID:(NSString *)packageID;

/// 包的可信来源类型（official_chain / trusted_public_key / confirmed_package / none）。
- (NSString *)anchorSourceForPackageID:(NSString *)packageID;

@end
