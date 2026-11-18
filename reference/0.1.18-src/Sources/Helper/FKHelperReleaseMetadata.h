#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 发布 / 构建元数据：描述当前 Helper 产物"是什么形态"。
///
/// 与逻辑身份（FKHelperIdentity）分离：身份回答"是谁"，本模型回答"当前产物是什么状态"。
/// 其中 binarySHA256 只是本地计算结果，不自动意味着可信；无可信发布锚点时完整性结论仍保持 Unknown。
/// 本模型字段完整不代表身份可信（见 HFM806）。
@interface FKHelperReleaseMetadata : NSObject <NSSecureCoding>

/// Helper 稳定标识。
@property (nonatomic, copy) NSString *helperID;
/// 版本号。
@property (nonatomic, copy) NSString *version;
/// 构建 ID。
@property (nonatomic, copy) NSString *buildID;
/// 协议版本字符串（例如 1.0）。
@property (nonatomic, copy) NSString *protocolVersion;
/// 架构（arm64 / arm64e）。
@property (nonatomic, copy) NSString *architecture;
/// 二进制大小（字节）；0 表示未知。
@property (nonatomic, assign) unsigned long long binarySize;
/// 本地计算出的二进制 SHA256（仅摘要比对用，不提供来源认证）。
@property (nonatomic, copy) NSString *binarySHA256;
/// 产物来源（official_repo / trusted_repo / manual / unknown）。
@property (nonatomic, copy) NSString *source;
/// 签名状态描述（unknown / valid / invalid / adhoc / unsigned / unsupported）。
@property (nonatomic, copy) NSString *signatureStatus;
/// 构建时间；缺失为 nil。
@property (nonatomic, strong, nullable) NSDate *buildDate;

/// 必要发布字段是否齐备（不含可信结论判断）。
- (BOOL)isComplete;

/// 元数据字典（用于报告与审计）。
- (NSDictionary *)JSONDictionary;

/// 由字典构造；非字典或关键字段全部缺失时返回空实例。
+ (nullable instancetype)metadataFromDictionary:(nullable NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
