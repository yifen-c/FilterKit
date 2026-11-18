#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// 会话密钥状态；本类只管理内存密钥，不负责持久化或跨进程分发。
typedef NS_ENUM(NSInteger, FKHelperKeyState) { FKHelperKeyStateEmpty = 0, FKHelperKeyStateActive, FKHelperKeyStateExpired, FKHelperKeyStateRevoked };
@interface FKHelperSessionKey : NSObject
@property (nonatomic, copy, readonly) NSString *keyID;
@property (nonatomic, strong, readonly) NSData *keyData;
@property (nonatomic, strong, readonly) NSDate *createdAt;
@property (nonatomic, strong, readonly) NSDate *expiresAt;
@property (nonatomic, assign, readonly) FKHelperKeyState state;
@end
@interface FKHelperKeyLifecycle : NSObject
/// 仅允许 60 秒至 24 小时有效期；默认一小时。
- (instancetype)initWithLifetime:(NSTimeInterval)lifetime NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
/// 使用系统随机源生成 256 bit 会话密钥；不会写入磁盘。
- (nullable FKHelperSessionKey *)createSessionKeyAtDate:(nullable NSDate *)date;
/// 到期后拒绝返回密钥；撤销后不可恢复。
- (nullable FKHelperSessionKey *)activeKeyAtDate:(nullable NSDate *)date;
- (void)revokeActiveKey;
@property (nonatomic, readonly) FKHelperKeyState state;
@end
NS_ASSUME_NONNULL_END
