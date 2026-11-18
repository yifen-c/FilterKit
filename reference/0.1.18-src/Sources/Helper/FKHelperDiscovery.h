#import <Foundation/Foundation.h>

@class FKHelperMetadata;

NS_ASSUME_NONNULL_BEGIN

/// Helper 发现分层状态。
/// 发现模块只负责候选文件与元数据采集，FKHelperDiscoveryVerified 不得由本模块自行产生；
/// 只有完整信任验证流程通过后，才由 Trust 汇总为可信状态。
typedef NS_ENUM(NSInteger, FKHelperDiscoveryStatus) {
    FKHelperDiscoveryNotFound = 0,   /// 无候选文件
    FKHelperDiscoveryFound,          /// 存在候选，形态基本完整
    FKHelperDiscoveryIncomplete,     /// 已找到但必要元数据缺失，或属普通系统工具候选
    FKHelperDiscoveryInvalid,        /// 文件类型不符合预期
    FKHelperDiscoveryVerified        /// 仅占位：Discovery 不产出该结论
};

@interface FKHelperDiscovery : NSObject

/// 依据元数据判定发现状态。
+ (FKHelperDiscoveryStatus)statusForMetadata:(nullable FKHelperMetadata *)metadata;

/// 从候选集合中选出最具代表性的元数据；无有效候选时返回 nil。
+ (nullable FKHelperMetadata *)bestMetadataForCandidates:(NSArray<NSDictionary *> *)candidates;

/// 采集全部候选元数据。
+ (NSArray<FKHelperMetadata *> *)metadataForCandidates:(NSArray<NSDictionary *> *)candidates;

/// 状态机器可读标识。
+ (NSString *)statusCodeForStatus:(FKHelperDiscoveryStatus)status;
/// 状态展示文案。
+ (NSString *)statusTextForStatus:(FKHelperDiscoveryStatus)status;

@end

NS_ASSUME_NONNULL_END
