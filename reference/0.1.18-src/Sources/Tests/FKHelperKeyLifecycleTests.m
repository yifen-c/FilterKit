#import "FKHelperKeyLifecycleTests.h"
#import "FKHelperKeyLifecycle.h"

@implementation FKHelperKeyLifecycleTests

+ (NSUInteger)checkCount {
    return 11;
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000];
    FKHelperKeyLifecycle *manager = [[FKHelperKeyLifecycle alloc] initWithLifetime:60];
    FKHelperSessionKey *key = [manager createSessionKeyAtDate:now];

    if (key.keyData.length != 32 || key.keyID.length != 32) {
        [failures addObject:@"KEY1401 应生成 256 bit 随机会话密钥"];
    }
    if (manager.state != FKHelperKeyStateActive) {
        [failures addObject:@"KEY1402 创建后状态应为 Active"];
    }
    if ([manager activeKeyAtDate:[now dateByAddingTimeInterval:59]] != key) {
        [failures addObject:@"KEY1403 未到期密钥应可读取"];
    }
    if ([manager activeKeyAtDate:[now dateByAddingTimeInterval:60]] != nil ||
        manager.state != FKHelperKeyStateExpired) {
        [failures addObject:@"KEY1404 到期密钥必须失效"];
    }

    BOOL expiredBufferCleared = YES;
    const uint8_t *expiredBytes = key.keyData.bytes;
    for (NSUInteger index = 0; index < key.keyData.length; index++) {
        if (expiredBytes[index] != 0) {
            expiredBufferCleared = NO;
            break;
        }
    }
    if (!expiredBufferCleared) {
        [failures addObject:@"KEY1411 到期密钥缓冲区应清零"];
    }

    FKHelperKeyLifecycle *invalidManager = [[FKHelperKeyLifecycle alloc] initWithLifetime:30];
    if ([invalidManager createSessionKeyAtDate:now]) {
        [failures addObject:@"KEY1405 小于最短期限应拒绝配置"];
    }

    FKHelperKeyLifecycle *revocationManager = [[FKHelperKeyLifecycle alloc] initWithLifetime:600];
    [revocationManager createSessionKeyAtDate:now];
    [revocationManager revokeActiveKey];
    if (revocationManager.state != FKHelperKeyStateRevoked ||
        [revocationManager activeKeyAtDate:now]) {
        [failures addObject:@"KEY1406 撤销后不得恢复密钥"];
    }

    FKHelperKeyLifecycle *rotationManager = [[FKHelperKeyLifecycle alloc] initWithLifetime:600];
    FKHelperSessionKey *oldKey = [rotationManager createSessionKeyAtDate:now];
    FKHelperSessionKey *newKey = [rotationManager createSessionKeyAtDate:now];
    if ([oldKey.keyID isEqualToString:newKey.keyID]) {
        [failures addObject:@"KEY1407 轮换必须生成新 Key ID"];
    }
    if (oldKey.state != FKHelperKeyStateRevoked) {
        [failures addObject:@"KEY1408 轮换后旧密钥必须撤销"];
    }

    BOOL oldBufferCleared = YES;
    const uint8_t *oldBytes = oldKey.keyData.bytes;
    for (NSUInteger index = 0; index < oldKey.keyData.length; index++) {
        if (oldBytes[index] != 0) {
            oldBufferCleared = NO;
            break;
        }
    }
    if (!oldBufferCleared) {
        [failures addObject:@"KEY1409 轮换后应清零旧密钥缓冲区"];
    }

    if ([manager createSessionKeyAtDate:nil]) {
        [failures addObject:@"KEY1410 非法时间必须拒绝"];
    }
    return failures.copy;
}

@end
