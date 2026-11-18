#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 会话级防重放器。只接受有效时间窗内、未使用过的请求标识与 Nonce。
@interface FKHelperReplayProtector : NSObject
- (instancetype)initWithMaximumEntries:(NSUInteger)maximumEntries maximumAge:(NSTimeInterval)maximumAge NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
/// 原子登记请求；重复 ID/Nonce、过期时间、未来时间或非法参数均拒绝。
- (BOOL)acceptRequestID:(NSString *)requestID nonce:(NSString *)nonce timestamp:(NSTimeInterval)timestamp now:(NSDate *)now;
/// 会话结束时清空缓存。
- (void)reset;
@property (nonatomic, readonly) NSUInteger count;
@end

NS_ASSUME_NONNULL_END
