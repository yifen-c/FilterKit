#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FKHelperTransportKind) {
    FKHelperTransportKindUndecided = 0,
    FKHelperTransportKindMachService,
    FKHelperTransportKindUnixSocket
};

/// 传输候选评估结果；没有设备证据时不自动选择实现。
@interface FKHelperTransportAssessment : NSObject
@property (nonatomic, copy, readonly) NSString *candidate;
@property (nonatomic, copy, readonly) NSString *status;
@property (nonatomic, copy, readonly) NSArray<NSString *> *missingEvidence;
@property (nonatomic, assign, readonly) BOOL eligible;
- (NSDictionary *)JSONDictionary;
@end

/// 仅根据明确的设备证据评估传输候选，不探测、不连接、不创建系统服务。
@interface FKHelperTransportAssessmentEngine : NSObject
- (NSArray<FKHelperTransportAssessment *> *)assessCandidatesWithEvidence:(NSDictionary *)evidence;
/// 当前证据是否足以作出唯一选择；两个候选都通过或都未通过均保持 Undecided。
- (FKHelperTransportKind)selectedTransportWithEvidence:(NSDictionary *)evidence;
@end

NS_ASSUME_NONNULL_END
