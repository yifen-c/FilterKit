#import "FKHelperFrameCodec.h"
#import <CoreFoundation/CoreFoundation.h>

static NSError *FKFrameError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"com.filterkit.helper.frame" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation FKHelperFrameCodec
- (instancetype)init { return [self initWithMaximumFrameLength:1024 * 1024]; }
- (instancetype)initWithMaximumFrameLength:(NSUInteger)maximumFrameLength {
    self = [super init];
    if (self) _maximumFrameLength = MAX(1, MIN(maximumFrameLength, 1024 * 1024));
    return self;
}
- (void)setMaximumFrameLength:(NSUInteger)maximumFrameLength { _maximumFrameLength = MAX(1, MIN(maximumFrameLength, 1024 * 1024)); }
- (NSData *)frameForPayload:(NSData *)payload error:(NSError **)error {
    if (![payload isKindOfClass:NSData.class] || payload.length == 0 || payload.length > self.maximumFrameLength || payload.length > UINT32_MAX) {
        if (error) *error = FKFrameError(1, @"帧载荷为空或超过长度上限");
        return nil;
    }
    uint32_t length = CFSwapInt32HostToBig((uint32_t)payload.length);
    NSMutableData *frame = [NSMutableData dataWithCapacity:sizeof(length) + payload.length];
    [frame appendBytes:&length length:sizeof(length)];
    [frame appendData:payload];
    return frame.copy;
}
- (NSData *)payloadFromFrame:(NSData *)frame error:(NSError **)error {
    if (![frame isKindOfClass:NSData.class] || frame.length < sizeof(uint32_t)) {
        if (error) *error = FKFrameError(2, @"帧头不完整");
        return nil;
    }
    uint32_t networkLength = 0;
    [frame getBytes:&networkLength length:sizeof(networkLength)];
    NSUInteger length = CFSwapInt32BigToHost(networkLength);
    if (length == 0 || length > self.maximumFrameLength || frame.length != sizeof(uint32_t) + length) {
        if (error) *error = FKFrameError(3, @"帧长度不匹配或超过上限");
        return nil;
    }
    return [frame subdataWithRange:NSMakeRange(sizeof(uint32_t), length)];
}
@end
