#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, FKHelperProtocolNegotiationStatus) { FKHelperProtocolNegotiationStatusRejected = 0, FKHelperProtocolNegotiationStatusAccepted, FKHelperProtocolNegotiationStatusInvalid };
@interface FKHelperProtocolNegotiationResult : NSObject
@property (nonatomic, assign, readonly) FKHelperProtocolNegotiationStatus status;
@property (nonatomic, assign, readonly) NSInteger major;
@property (nonatomic, assign, readonly) NSInteger minor;
@property (nonatomic, copy, readonly) NSString *reasonCode;
@end
/// 严格协商协议范围：主版本必须相同，次版本选择双方共同支持的最高值。
@interface FKHelperProtocolNegotiator : NSObject
- (FKHelperProtocolNegotiationResult *)negotiateClientVersions:(NSArray<NSDictionary *> *)clientVersions helperVersions:(NSArray<NSDictionary *> *)helperVersions;
@end
NS_ASSUME_NONNULL_END
