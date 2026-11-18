#import "FKHelperReplayProtector.h"
#import <math.h>

@interface FKHelperReplayProtector ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *seen;
@property (nonatomic, assign) NSUInteger maximumEntries;
@property (nonatomic, assign) NSTimeInterval maximumAge;
@end

@implementation FKHelperReplayProtector
- (instancetype)init { return [self initWithMaximumEntries:4096 maximumAge:300.0]; }
- (instancetype)initWithMaximumEntries:(NSUInteger)maximumEntries maximumAge:(NSTimeInterval)maximumAge {
    self = [super init];
    if (self) {
        _maximumEntries = MAX(1, MIN(maximumEntries, 65536));
        _maximumAge = (isfinite(maximumAge) && maximumAge >= 1.0 && maximumAge <= 3600.0) ? maximumAge : 300.0;
        _seen = [NSMutableDictionary dictionary];
    }
    return self;
}
- (NSUInteger)count { @synchronized (self) { return self.seen.count; } }
- (BOOL)acceptRequestID:(NSString *)requestID nonce:(NSString *)nonce timestamp:(NSTimeInterval)timestamp now:(NSDate *)now {
    if (![requestID isKindOfClass:NSString.class] || requestID.length == 0 || requestID.length > 128 ||
        ![nonce isKindOfClass:NSString.class] || nonce.length < 16 || nonce.length > 128 ||
        !isfinite(timestamp) || ![now isKindOfClass:NSDate.class]) return NO;
    NSTimeInterval current = now.timeIntervalSince1970;
    if (fabs(current - timestamp) > self.maximumAge) return NO;
    @synchronized (self) {
        NSArray<NSString *> *keys = self.seen.allKeys;
        for (NSString *key in keys) if (current - self.seen[key].timeIntervalSince1970 > self.maximumAge) [self.seen removeObjectForKey:key];
        NSString *requestKey = [@"r:" stringByAppendingString:requestID];
        NSString *nonceKey = [@"n:" stringByAppendingString:nonce];
        if (self.seen[requestKey] || self.seen[nonceKey]) return NO;
        if (self.seen.count + 2 > self.maximumEntries) {
            // 缓存满时拒绝新请求，不淘汰仍在有效期内的防重放记录。
            return NO;
        }
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
        self.seen[requestKey] = date;
        self.seen[nonceKey] = date;
        return YES;
    }
}
- (void)reset { @synchronized (self) { [self.seen removeAllObjects]; } }
@end
