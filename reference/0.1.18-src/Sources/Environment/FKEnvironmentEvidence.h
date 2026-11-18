#import <Foundation/Foundation.h>

/// 证据置信度：verified 表示有直接可核对依据；partial 为部分依据；unknown 为证据不足。
typedef NS_ENUM(NSInteger, FKEvidenceConfidence) {
    FKEvidenceConfidenceUnknown = 0,
    FKEvidenceConfidencePartial,
    FKEvidenceConfidenceVerified
};

/// 单项环境探测证据。不只记录结论，还保留路径、存在性、可读性、来源与置信度，便于追溯。
@interface FKEnvironmentEvidence : NSObject

/// 证据项标识（jbroot / injector / dynamic_libraries / package_metadata 等）
@property (nonatomic, copy) NSString *evidenceKey;
/// 探测到的路径；无路径时为空
@property (nonatomic, copy) NSString *path;
/// 路径是否存在
@property (nonatomic, assign) BOOL exists;
/// 是否为目录
@property (nonatomic, assign) BOOL isDirectory;
/// 是否可读；不可读不等于环境不兼容，可能是沙盒权限或路径映射差异
@property (nonatomic, assign) BOOL readable;
/// 证据来源（filesystem_probe / package_metadata / launchd_registration / derived）
@property (nonatomic, copy) NSString *source;
/// 证据置信度
@property (nonatomic, assign) FKEvidenceConfidence confidence;
/// 补充说明或存疑原因
@property (nonatomic, copy) NSString *detail;

+ (instancetype)evidenceWithKey:(NSString *)key;
+ (instancetype)evidenceFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)JSONDictionary;

@end
