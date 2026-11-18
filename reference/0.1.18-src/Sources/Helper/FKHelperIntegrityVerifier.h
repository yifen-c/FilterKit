#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 文件完整性状态。本地摘要计算成功只说明可计算当前文件摘要；
/// 只有与可信发布清单锚点匹配，才允许判为 Verified。
typedef NS_ENUM(NSInteger, FKHelperIntegrityStatus) {
    FKHelperIntegrityUnknown = 0,      /// 无可信锚点，无法判定完整性
    FKHelperIntegrityVerified,         /// 本地摘要与可信发布记录匹配
    FKHelperIntegrityMismatch,         /// 摘要与可信记录不一致（文件被替换或损坏）
    FKHelperIntegrityUnavailable       /// 摘要计算失败或文件不可读
};

/// 完整性验证结果：携带本地计算摘要、可信锚点摘要、状态与机器可读原因码。
/// 摘要计算失败不得当作空摘要继续比对；无可信锚点时状态保持 Unknown。
@interface FKHelperIntegrityResult : NSObject

/// 完整性状态。
@property (nonatomic, assign) FKHelperIntegrityStatus status;
/// 本地计算出的 SHA-256（十六进制）；计算失败为空。
@property (nonatomic, copy) NSString *calculatedSHA256;
/// 可信发布清单中的锚点 SHA-256；无可信记录为空。
@property (nonatomic, copy) NSString *expectedSHA256;
/// 机器可读原因码。
@property (nonatomic, copy) NSString *reasonCode;

- (NSDictionary *)JSONDictionary;

@end

@interface FKHelperIntegrityVerifier : NSObject

/// 评估完整性。trustedSHA256 为可信发布锚点；为空时保持 Unknown，不据此判通过。
/// @param path 候选可执行路径
/// @param trustedSHA256 可信发布清单中的 SHA-256；无可信记录时传 nil
/// @param reasons 追加未通过或存疑说明
+ (FKHelperIntegrityStatus)verifyIntegrityWithPath:(NSString *)path
                                     trustedSHA256:(nullable NSString *)trustedSHA256
                                            reasons:(NSMutableArray<NSString *> *)reasons;

/// 计算本地文件 SHA-256（十六进制）；读取失败返回 nil。
+ (nullable NSString *)localSHA256ForPath:(NSString *)path;

/// 结果化完整性验证：返回状态、本地/锚点摘要与原因码；不把计算失败当作空摘要比对。
- (FKHelperIntegrityResult *)verifyFileAtPath:(NSString *)path expectedSHA256:(nullable NSString *)expectedSHA256;

@end

NS_ASSUME_NONNULL_END
