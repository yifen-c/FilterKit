#import "FKHelperTransportTests.h"
#import "FKHelperTransport.h"
#import "FKHelperTestTransport.h"
#import "FKHelperTransportState.h"
#import "FKHelperReadOnlyClient.h"
#import "FKMockHelperClient.h"

@implementation FKHelperTransportTests

+ (NSUInteger)checkCount { return 7; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // TRN801：Transport 接口完整。
    FKHelperTestTransport *transport = [[FKHelperTestTransport alloc] init];
    if (![transport respondsToSelector:@selector(connected)] ||
        ![transport respondsToSelector:@selector(connectWithCompletion:)] ||
        ![transport respondsToSelector:@selector(sendData:completion:)] ||
        ![transport respondsToSelector:@selector(disconnect)]) {
        [failures addObject:@"TRN801 传输接口缺少必要方法"];
    }

    // TRN802：支持连接状态（初始 Idle，模拟连接后不得进入 Connected）。
    if (transport.status.state != FKHelperTransportStateIdle) {
        [failures addObject:@"TRN802 传输初始状态应为 Idle"];
    }
    [transport connectWithCompletion:^(BOOL success, NSError *_Nullable error) {
        (void)success; (void)error;
    }];
    if (transport.status.state == FKHelperTransportStateConnected) {
        [failures addObject:@"TRN802 模拟传输不得进入 Connected 状态"];
    }

    // TRN803：支持断开状态。
    [transport disconnect];
    if (transport.status.state != FKHelperTransportStateDisconnected) {
        [failures addObject:@"TRN803 断开后应进入 Disconnected 状态"];
    }

    // TRN804：支持错误返回。
    __block BOOL connectSuccess = YES;
    __block NSError *connectError = nil;
    [transport connectWithCompletion:^(BOOL success, NSError *_Nullable error) {
        connectSuccess = success;
        connectError = error;
    }];
    if (connectSuccess || connectError == nil) {
        [failures addObject:@"TRN804 模拟连接应返回失败与错误"];
    }

    // TRN805：支持超时状态。
    FKHelperTestTransport *timeoutTransport = [[FKHelperTestTransport alloc] init];
    timeoutTransport.simulateTimeout = YES;
    __block NSError *timeoutError = nil;
    [timeoutTransport connectWithCompletion:^(BOOL success, NSError *_Nullable error) {
        (void)success;
        timeoutError = error;
    }];
    if (timeoutTransport.status.state != FKHelperTransportStateTimeout ||
        timeoutError.code != FKHelperTransportErrorTimeout) {
        [failures addObject:@"TRN805 超时模拟应进入 Timeout 状态并返回超时错误"];
    }

    // TRN806：Client 不依赖具体传输实现，经协议注入；未连接时只读请求安全拒绝。
    id<FKHelperTransport> abstractTransport = [[FKHelperTestTransport alloc] init];
    FKHelperReadOnlyClient *client = [[FKHelperReadOnlyClient alloc] initWithTransport:abstractTransport];
    if (client.connected) {
        [failures addObject:@"TRN806 未验证传输不应报告为已连接"];
    }
    __block NSError *clientError = nil;
    [client requestHelperInfo:^(NSDictionary *_Nullable result, NSError *_Nullable error) {
        (void)result;
        clientError = error;
    }];
    if (clientError == nil) {
        [failures addObject:@"TRN806 无可用端点时只读请求应返回错误"];
    }
    FKHelperReadOnlyClient *noTransportClient = [[FKHelperReadOnlyClient alloc] initWithTransport:nil];
    __block NSError *missingError = nil;
    [noTransportClient requestPluginList:^(NSArray *_Nullable plugins, NSError *_Nullable error) {
        (void)plugins;
        missingError = error;
    }];
    if (missingError == nil) {
        [failures addObject:@"TRN806 未配置传输时应返回不可用错误"];
    }

    // TRN807：Test Transport / Mock 客户端不得被报告成真实连接。
    if (!transport.isMock || transport.connected) {
        [failures addObject:@"TRN807 测试传输必须标注 Mock 且未连接"];
    }
    FKMockHelperClient *mockClient = [[FKMockHelperClient alloc] init];
    if (!mockClient.isMock) {
        [failures addObject:@"TRN807 模拟客户端必须标注 isMock"];
    }
    __block NSDictionary *mockInfo = nil;
    [mockClient requestHelperInfo:^(NSDictionary *_Nullable result, NSError *_Nullable error) {
        (void)error;
        mockInfo = result;
    }];
    if (![mockInfo[@"mock"] boolValue]) {
        [failures addObject:@"TRN807 模拟 Helper 信息必须携带 mock 标记"];
    }
    __block NSArray *mockPlugins = nil;
    [mockClient requestPluginList:^(NSArray *_Nullable plugins, NSError *_Nullable error) {
        (void)error;
        mockPlugins = plugins;
    }];
    if (mockPlugins.count != 1 || ![mockPlugins.firstObject[@"mock"] boolValue]) {
        [failures addObject:@"TRN807 模拟插件列表必须标注 mock"];
    }

    return failures.copy;
}

@end
