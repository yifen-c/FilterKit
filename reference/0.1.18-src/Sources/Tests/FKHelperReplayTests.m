#import "FKHelperReplayTests.h"
#import "FKHelperReplayProtector.h"

@implementation FKHelperReplayTests
+ (NSUInteger)checkCount { return 8; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray *failures = [NSMutableArray array];
    FKHelperReplayProtector *guard = [[FKHelperReplayProtector alloc] initWithMaximumEntries:8 maximumAge:60];
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000];
    if (![guard acceptRequestID:@"req-1" nonce:@"nonce-000000000001" timestamp:1000 now:now]) [failures addObject:@"RPL1301 首次有效请求应被接受"];
    if ([guard acceptRequestID:@"req-1" nonce:@"nonce-000000000002" timestamp:1000 now:now]) [failures addObject:@"RPL1302 重复请求 ID 应拒绝"];
    if ([guard acceptRequestID:@"req-2" nonce:@"nonce-000000000001" timestamp:1000 now:now]) [failures addObject:@"RPL1303 重复 Nonce 应拒绝"];
    if ([guard acceptRequestID:@"req-3" nonce:@"nonce-000000000003" timestamp:900 now:now]) [failures addObject:@"RPL1304 过期请求应拒绝"];
    if ([guard acceptRequestID:@"req-4" nonce:@"nonce-000000000004" timestamp:1100 now:now]) [failures addObject:@"RPL1305 超前时间戳应拒绝"];
    if ([guard acceptRequestID:@"" nonce:@"nonce-000000000005" timestamp:1000 now:now]) [failures addObject:@"RPL1306 空请求 ID 应拒绝"];
    if ([guard acceptRequestID:@"req-7" nonce:@"short" timestamp:1000 now:now]) [failures addObject:@"RPL1307 短 Nonce 应拒绝"];
    [guard reset];
    if (guard.count != 0 || ![guard acceptRequestID:@"req-1" nonce:@"nonce-000000000001" timestamp:1000 now:now]) [failures addObject:@"RPL1308 会话重置应清空防重放记录"];
    return failures.copy;
}
@end
