#import "FKHelperFrameTests.h"
#import <CoreFoundation/CoreFoundation.h>
#import "FKHelperFrameCodec.h"

@implementation FKHelperFrameTests
+ (NSUInteger)checkCount { return 8; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *failures = [NSMutableArray array];
    FKHelperFrameCodec *codec = [[FKHelperFrameCodec alloc] initWithMaximumFrameLength:64];
    NSData *payload = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *frame = [codec frameForPayload:payload error:&error];
    if (frame.length != 9 || error) [failures addObject:@"FRM1301 编码应添加四字节长度头"];
    NSData *decoded = [codec payloadFromFrame:frame error:&error];
    if (![decoded isEqualToData:payload]) [failures addObject:@"FRM1302 完整帧应正确解码"];
    if ([codec frameForPayload:[NSData data] error:&error] != nil) [failures addObject:@"FRM1303 空载荷应拒绝"];
    NSData *shortHeader = [NSData dataWithBytes:"\0\0" length:2];
    if ([codec payloadFromFrame:shortHeader error:&error] != nil) [failures addObject:@"FRM1304 不完整帧头应拒绝"];
    uint32_t tooLarge = CFSwapInt32HostToBig(65);
    NSMutableData *oversized = [NSMutableData dataWithBytes:&tooLarge length:4];
    [oversized appendData:[NSMutableData dataWithLength:65]];
    if ([codec payloadFromFrame:oversized error:&error] != nil) [failures addObject:@"FRM1305 超限帧应拒绝"];
    NSMutableData *trailing = [frame mutableCopy];
    uint8_t extra = 0; [trailing appendBytes:&extra length:1];
    if ([codec payloadFromFrame:trailing error:&error] != nil) [failures addObject:@"FRM1306 帧尾随数据应拒绝"];
    uint32_t zero = 0;
    NSData *zeroFrame = [NSData dataWithBytes:&zero length:4];
    if ([codec payloadFromFrame:zeroFrame error:&error] != nil) [failures addObject:@"FRM1307 零长度帧应拒绝"];
    FKHelperFrameCodec *defaultCodec = [FKHelperFrameCodec new];
    if (defaultCodec.maximumFrameLength != 1024 * 1024) [failures addObject:@"FRM1308 默认帧上限应为 1 MiB"];
    return failures.copy;
}
@end
