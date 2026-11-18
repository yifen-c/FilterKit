#import "FKHelperHandshakeTests.h"
#import "FKHelperHandshakeValidator.h"
#import "FKHelperIPCHandshake.h"
#import "FKHelperIdentity.h"
#import "FKHelperTrust.h"
#import "FKHelperSession.h"

@implementation FKHelperHandshakeTests

+ (NSUInteger)checkCount { return 12; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperHandshakeValidator *validator = [FKHelperHandshakeValidator new];
    NSString *expectedID = [FKHelperIdentity expectedIdentity].helperID;

    FKHelperIPCHandshakeResponse *(^makeResponse)(NSString *, NSInteger, NSArray *) =
        ^(NSString *helperID, NSInteger proto, NSArray *caps) {
        FKHelperIPCHandshakeResponse *r = [FKHelperIPCHandshakeResponse new];
        r.helperID = helperID;
        r.protocolVersion = proto;
        r.status = @"accepted";
        r.capabilities = caps;
        return r;
    };
    FKHelperTrustReport *(^makeReport)(BOOL ipc, NSString *manifest) = ^(BOOL ipc, NSString *manifest) {
        FKHelperTrustReport *r = [FKHelperTrustReport new];
        r.ipcVerified = ipc;
        r.manifestStatus = manifest;
        r.identityVerified = YES;
        return r;
    };

    NSArray *okCaps = @[@"helper.info", @"plugin.list"];

    // HSK901：响应缺失 → response_missing。
    if (![[validator rejectReasonsForRequestID:@"req-1" nonce:@"n1" timestamp:0 response:nil trustReport:makeReport(YES, @"verified")] containsObject:@"response_missing"]) {
        [failures addObject:@"HSK901 响应缺失应拒绝"];
    }

    // HSK902：RequestID 缺失。
    NSArray *r902 = [validator rejectReasonsForRequestID:@"" nonce:@"n1" timestamp:0 response:makeResponse(expectedID, 1, okCaps) trustReport:makeReport(YES, @"verified")];
    if (![r902 containsObject:@"request_id_missing"]) [failures addObject:@"HSK902 缺 RequestID 应拒绝"];

    // HSK903：Nonce 缺失。
    NSArray *r903 = [validator rejectReasonsForRequestID:@"req-1" nonce:@"" timestamp:0 response:makeResponse(expectedID, 1, okCaps) trustReport:makeReport(YES, @"verified")];
    if (![r903 containsObject:@"nonce_missing"]) [failures addObject:@"HSK903 缺 Nonce 应拒绝"];

    // HSK904：时间戳过期。
    NSTimeInterval old = [[NSDate date] timeIntervalSince1970] - 600;
    NSArray *r904 = [validator rejectReasonsForRequestID:@"req-1" nonce:@"n1" timestamp:old response:makeResponse(expectedID, 1, okCaps) trustReport:makeReport(YES, @"verified")];
    if (![r904 containsObject:@"timestamp_expired"]) [failures addObject:@"HSK904 过期时间戳应拒绝"];

    // HSK905：协议版本不兼容。
    NSArray *r905 = [validator rejectReasonsForRequestID:@"req-1" nonce:@"n1" timestamp:0 response:makeResponse(expectedID, 99, okCaps) trustReport:makeReport(YES, @"verified")];
    if (![r905 containsObject:@"protocol_incompatible"]) [failures addObject:@"HSK905 协议不兼容应拒绝"];

    // HSK906：Helper ID 不符。
    NSArray *r906 = [validator rejectReasonsForRequestID:@"req-1" nonce:@"n1" timestamp:0 response:makeResponse(@"com.other.helper", 1, okCaps) trustReport:makeReport(YES, @"verified")];
    if (![r906 containsObject:@"helper_id_mismatch"]) [failures addObject:@"HSK906 标识不符应拒绝"];

    // HSK907：清单未验证。
    NSArray *r907 = [validator rejectReasonsForRequestID:@"req-1" nonce:@"n1" timestamp:0 response:makeResponse(expectedID, 1, okCaps) trustReport:makeReport(YES, @"unavailable")];
    if (![r907 containsObject:@"manifest_unverified"]) [failures addObject:@"HSK907 清单未验证应拒绝"];

    // HSK908：对端未验证。
    NSArray *r908 = [validator rejectReasonsForRequestID:@"req-1" nonce:@"n1" timestamp:0 response:makeResponse(expectedID, 1, okCaps) trustReport:makeReport(NO, @"verified")];
    if (![r908 containsObject:@"peer_unverified"]) [failures addObject:@"HSK908 对端未验证应拒绝"];

    // HSK909：响应含写 / 未知能力。
    NSArray *r909 = [validator rejectReasonsForRequestID:@"req-1" nonce:@"n1" timestamp:0 response:makeResponse(expectedID, 1, @[@"plugin.enable"]) trustReport:makeReport(YES, @"verified")];
    if (![r909 containsObject:@"unknown_capability"]) [failures addObject:@"HSK909 写能力应拒绝"];

    // HSK910：齐备请求 / 响应 / 报告 → 无拒绝原因。
    NSArray *r910 = [validator rejectReasonsForRequestID:@"req-1" nonce:@"n1" timestamp:0 response:makeResponse(expectedID, 1, okCaps) trustReport:makeReport(YES, @"verified")];
    if (r910.count != 0) [failures addObject:[NSString stringWithFormat:@"HSK910 齐备应通过，实际原因：%@", r910]];

    // HSK911：会话流转到只读就绪，对端验证后置位才就绪。
    FKHelperSession *session = [FKHelperSession new];
    [session transitionToState:FKHelperSessionConnecting];
    [session transitionToState:FKHelperSessionHandshaking];
    [session transitionToState:FKHelperSessionVerifying];
    if (session.isReadOnlyReady) [failures addObject:@"HSK911 验证完成前不应就绪"];
    session.peerVerified = YES;
    [session transitionToState:FKHelperSessionReadyReadOnly];
    if (!session.isReadOnlyReady) [failures addObject:@"HSK911 验证通过后应进入只读就绪"];

    // HSK912：关闭会话撤销对端结论。
    [session closeSession];
    if (session.peerVerified || session.isReadOnlyReady) [failures addObject:@"HSK912 关闭后应撤销授权"];

    return failures.copy;
}

@end
