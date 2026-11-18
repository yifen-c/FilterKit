#import "FKHelperKeyLifecycle.h"
#import <stdlib.h>
#import <string.h>

@interface FKHelperSessionKey ()
@property (nonatomic, copy, readwrite) NSString *keyID;
@property (nonatomic, strong, readwrite) NSData *keyData;
@property (nonatomic, strong, readwrite) NSDate *createdAt;
@property (nonatomic, strong, readwrite) NSDate *expiresAt;
@property (nonatomic, assign, readwrite) FKHelperKeyState state;
@end
@implementation FKHelperSessionKey
@end

@interface FKHelperKeyLifecycle ()
@property (nonatomic, assign) NSTimeInterval lifetime;
@property (nonatomic, strong) FKHelperSessionKey *currentKey;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) FKHelperKeyState terminalState;
@end
@implementation FKHelperKeyLifecycle
- (void)wipeCurrentKeyLocked {
    if (!_currentKey) return;
    if ([_currentKey.keyData isKindOfClass:NSMutableData.class]) {
        NSMutableData *buffer = (NSMutableData *)_currentKey.keyData;
        if (buffer.length) memset(buffer.mutableBytes, 0, buffer.length);
    }
    _currentKey.state = FKHelperKeyStateRevoked;
    _currentKey = nil;
}
- (instancetype)init { return [self initWithLifetime:3600]; }
- (instancetype)initWithLifetime:(NSTimeInterval)lifetime {
    self = [super init];
    if (self) { _lifetime = (lifetime >= 60.0 && lifetime <= 86400.0) ? lifetime : 0; _lock = [NSLock new]; _terminalState = FKHelperKeyStateEmpty; }
    return self;
}
- (FKHelperSessionKey *)createSessionKeyAtDate:(NSDate *)date {
    if (![date isKindOfClass:NSDate.class] || self.lifetime <= 0) return nil;
    [_lock lock];
    [self wipeCurrentKeyLocked];
    uint8_t bytes[32] = {0};
    uint8_t identifierBytes[16] = {0};
    arc4random_buf(bytes, sizeof(bytes));
    arc4random_buf(identifierBytes, sizeof(identifierBytes));
    NSMutableString *identifier = [NSMutableString stringWithCapacity:32];
    for (NSUInteger i = 0; i < sizeof(identifierBytes); i++) [identifier appendFormat:@"%02x", identifierBytes[i]];
    FKHelperSessionKey *item = [FKHelperSessionKey new];
    item.keyID = identifier.copy;
    item.keyData = [NSMutableData dataWithBytes:bytes length:sizeof(bytes)];
    item.createdAt = date;
    item.expiresAt = [date dateByAddingTimeInterval:_lifetime];
    item.state = FKHelperKeyStateActive;
    memset(bytes, 0, sizeof(bytes));
    memset(identifierBytes, 0, sizeof(identifierBytes));
    self.currentKey = item;
    self.terminalState = FKHelperKeyStateActive;
    [_lock unlock];
    return item;
}
- (FKHelperSessionKey *)activeKeyAtDate:(NSDate *)date {
    if (![date isKindOfClass:NSDate.class]) return nil;
    [_lock lock];
    FKHelperSessionKey *result = nil;
    if (_currentKey && _currentKey.state == FKHelperKeyStateActive) {
        if ([date compare:_currentKey.expiresAt] != NSOrderedAscending) {
            if ([_currentKey.keyData isKindOfClass:NSMutableData.class]) {
                NSMutableData *buffer = (NSMutableData *)_currentKey.keyData;
                if (buffer.length) memset(buffer.mutableBytes, 0, buffer.length);
            }
            _currentKey.state = FKHelperKeyStateExpired;
            self.terminalState = FKHelperKeyStateExpired;
            _currentKey = nil;
        } else result = _currentKey;
    }
    [_lock unlock];
    return result;
}
- (void)revokeActiveKey {
    [_lock lock];
    [self wipeCurrentKeyLocked];
    self.terminalState = FKHelperKeyStateRevoked;
    [_lock unlock];
}
- (FKHelperKeyState)state {
    [_lock lock]; FKHelperKeyState value = _currentKey ? _currentKey.state : _terminalState; [_lock unlock]; return value;
}
@end
