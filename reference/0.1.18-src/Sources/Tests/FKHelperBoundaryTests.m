#import "FKHelperBoundaryTests.h"
#import "FKHelperReadOnlyClient.h"
#import "FKHelperMessage.h"
#import "FKHelperCapabilities.h"
#import "FKHelperTransport.h"
#import "FKHelperSession.h"
#import "FKHelperTrust.h"
#import "FKHelperIPCAuditEvent.h"

@interface FKBoundaryTestTransport : NSObject <FKHelperTransport>
@property (nonatomic, strong) FKHelperTransportStatus *status;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, assign) BOOL isMock;
@property (nonatomic, assign) NSUInteger sendCount;
@property (nonatomic, copy) FKHelperMessage *(^responseFactory)(FKHelperMessage *request);
@property (nonatomic, copy) NSString *lastMethod;
@property (nonatomic, assign) BOOL didDisconnect;
@end

@implementation FKBoundaryTestTransport
- (instancetype)init {
    self = [super init];
    if (self) {
        _status = [FKHelperTransportStatus new];
        _status.state = FKHelperTransportStateConnected;
        _connected = YES;
        _isMock = NO;
    }
    return self;
}
- (void)connectWithCompletion:(void (^)(BOOL, NSError * _Nullable))completion {
    if (completion) completion(self.connected, nil);
}
- (void)sendData:(NSData *)data completion:(void (^)(NSData * _Nullable, NSError * _Nullable))completion {
    self.sendCount += 1;
    FKHelperMessage *request = [FKHelperMessage messageFromData:data error:nil];
    self.lastMethod = request.method;
    FKHelperMessage *response = self.responseFactory ? self.responseFactory(request) : nil;
    if (completion) completion([response JSONData:nil], nil);
}
- (void)disconnect {
    self.didDisconnect = YES;
    self.connected = NO;
    self.status.state = FKHelperTransportStateDisconnected;
}
@end

@implementation FKHelperBoundaryTests

+ (NSUInteger)checkCount { return 14; }

+ (FKBoundaryTestTransport *)transportWithPayload:(NSDictionary *)payload {
    FKBoundaryTestTransport *transport = [FKBoundaryTestTransport new];
    transport.responseFactory = ^FKHelperMessage *(FKHelperMessage *request) {
        FKHelperMessage *response = [FKHelperMessage new];
        response.messageType = FKHelperMessageResponse;
        response.requestID = request.requestID;
        response.method = request.method;
        response.protocolMajor = request.protocolMajor;
        response.protocolMinor = request.protocolMinor;
        response.responseStatus = @"ok";
        response.payload = payload ?: @{};
        return response;
    };
    return transport;
}

+ (FKHelperReadOnlyClient *)clientWithVerifiedTestContext:(id<FKHelperTransport>)transport {
    // 仅用于单元测试的完整证据夹具，不代表设备上存在真实可信 Helper。
    FKHelperSession *session = [FKHelperSession new];
    session.peerVerified = YES;
    session.sessionID = @"session-test-001";
    [session transitionToState:FKHelperSessionReadyReadOnly];

    FKHelperTrustReport *report = [FKHelperTrustReport new];
    report.identityVerified = YES;
    report.helperID = @"com.filterkit.helper";
    report.buildID = @"FKH-0118";
    report.signatureVerified = YES;
    report.signatureStatus = FKSignatureStatusValid;
    report.manifestStatus = @"verified";
    report.integrityStatus = FKHelperIntegrityVerified;
    report.permissionVerified = YES;
    report.permissionReadOnly = YES;
    report.permissionWrite = NO;
    report.ipcVerified = YES;
    report.ipcStatus = FKHelperIPCConnected;

    FKHelperCapabilities *capabilities = [FKHelperCapabilities capabilitiesWithSet:[FKHelperCapabilities readOnlyWhitelist]];
    return [[FKHelperReadOnlyClient alloc] initWithTransport:transport session:session trustReport:report capabilities:capabilities];
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // BND1001：即使 Mock 错误地报告 connected=YES，也不得进入生产只读客户端。
    FKBoundaryTestTransport *mock = [self transportWithPayload:@{@"source": @"mock"}];
    mock.isMock = YES;
    mock.status.isMock = YES;
    FKHelperReadOnlyClient *mockClient = [[FKHelperReadOnlyClient alloc] initWithTransport:mock];
    __block NSError *mockError = nil;
    [mockClient requestHelperInfo:^(NSDictionary *result, NSError *error) { (void)result; mockError = error; }];
    if (mockClient.connected || mock.sendCount != 0 || mockError == nil) {
        [failures addObject:@"BND1001 Mock 传输即使自报连接也必须被拒绝"];
    }

    // BND1013：真实传输即使 connected=YES，没有 ReadyReadOnly 会话和信任报告也不能发请求。
    FKBoundaryTestTransport *connectedButUnverified = [self transportWithPayload:@{@"source": @"test"}];
    FKHelperReadOnlyClient *unverifiedClient = [[FKHelperReadOnlyClient alloc] initWithTransport:connectedButUnverified];
    __block NSError *unverifiedError = nil;
    [unverifiedClient requestHelperInfo:^(NSDictionary *result, NSError *error) { (void)result; unverifiedError = error; }];
    if (!unverifiedClient.connected || unverifiedClient.readyReadOnly || connectedButUnverified.sendCount != 0 || unverifiedError == nil) {
        [failures addObject:@"BND1013 未验证会话不得发送只读请求"];
    }

    // BND1002：响应 Request ID 不匹配必须拒绝。
    FKBoundaryTestTransport *wrongID = [self transportWithPayload:@{@"source": @"test"}];
    wrongID.responseFactory = ^FKHelperMessage *(FKHelperMessage *request) {
        FKHelperMessage *r = [FKHelperMessage new]; r.messageType = FKHelperMessageResponse;
        r.requestID = @"other-request"; r.method = request.method; r.responseStatus = @"ok"; r.payload = @{}; return r;
    };
    __block NSError *wrongIDError = nil;
    [[self clientWithVerifiedTestContext:wrongID] requestHelperInfo:^(NSDictionary *result, NSError *error) { (void)result; wrongIDError = error; }];
    if (wrongIDError == nil) [failures addObject:@"BND1002 错误 Request ID 响应必须拒绝"];

    // BND1003：响应方法不匹配必须拒绝。
    FKBoundaryTestTransport *wrongMethod = [self transportWithPayload:@{}];
    wrongMethod.responseFactory = ^FKHelperMessage *(FKHelperMessage *request) {
        FKHelperMessage *r = [FKHelperMessage new]; r.messageType = FKHelperMessageResponse;
        r.requestID = request.requestID; r.method = @"plugin.list"; r.responseStatus = @"ok"; r.payload = @{}; return r;
    };
    __block NSError *wrongMethodError = nil;
    [[self clientWithVerifiedTestContext:wrongMethod] requestHelperInfo:^(NSDictionary *result, NSError *error) { (void)result; wrongMethodError = error; }];
    if (wrongMethodError == nil) [failures addObject:@"BND1003 错误方法响应必须拒绝"];

    // BND1004：响应协议版本不匹配必须拒绝。
    FKBoundaryTestTransport *wrongVersion = [self transportWithPayload:@{}];
    wrongVersion.responseFactory = ^FKHelperMessage *(FKHelperMessage *request) {
        FKHelperMessage *r = [FKHelperMessage new]; r.messageType = FKHelperMessageResponse;
        r.requestID = request.requestID; r.method = request.method; r.protocolMajor = 2;
        r.responseStatus = @"ok"; r.payload = @{}; return r;
    };
    __block NSError *wrongVersionError = nil;
    [[self clientWithVerifiedTestContext:wrongVersion] requestHelperInfo:^(NSDictionary *result, NSError *error) { (void)result; wrongVersionError = error; }];
    if (wrongVersionError == nil) [failures addObject:@"BND1004 不兼容协议响应必须拒绝"];

    // BND1005：Helper error 响应必须映射为客户端错误。
    FKBoundaryTestTransport *rejected = [self transportWithPayload:@{}];
    rejected.responseFactory = ^FKHelperMessage *(FKHelperMessage *request) {
        FKHelperMessage *r = [FKHelperMessage new]; r.messageType = FKHelperMessageResponse;
        r.requestID = request.requestID; r.method = request.method; r.responseStatus = @"error";
        r.errorPayload = @{@"code": @6, @"reason": @"peer_unverified"}; return r;
    };
    __block NSError *rejectedError = nil;
    [[self clientWithVerifiedTestContext:rejected] requestHelperInfo:^(NSDictionary *result, NSError *error) { (void)result; rejectedError = error; }];
    if (rejectedError == nil || ![rejectedError.userInfo[@"reasonCode"] isEqualToString:@"peer_unverified"]) {
        [failures addObject:@"BND1005 Helper error 响应必须保留原因码"];
    }

    // BND1006：能力响应混入写能力时整份拒绝。
    FKBoundaryTestTransport *writeCapability = [self transportWithPayload:@{@"capabilities": @[@"plugin.list", @"plugin.enable"]}];
    __block NSError *capabilityError = nil;
    [[self clientWithVerifiedTestContext:writeCapability] requestCapabilities:^(FKHelperCapabilities *caps, NSError *error) { (void)caps; capabilityError = error; }];
    if (capabilityError == nil) [failures addObject:@"BND1006 能力响应包含写能力必须整体拒绝"];

    // BND1007：能力响应缺少数组必须拒绝，而不是静默变成空能力。
    FKBoundaryTestTransport *missingCaps = [self transportWithPayload:@{@"source": @"test"}];
    __block NSError *missingCapsError = nil;
    [[self clientWithVerifiedTestContext:missingCaps] requestCapabilities:^(FKHelperCapabilities *caps, NSError *error) { (void)caps; missingCapsError = error; }];
    if (missingCapsError == nil) [failures addObject:@"BND1007 缺少 capabilities 数组必须拒绝"];

    // BND1008：插件列表包含非字典记录必须拒绝。
    FKBoundaryTestTransport *badPlugins = [self transportWithPayload:@{@"plugins": @[@"not-a-dictionary"]}];
    __block NSError *badPluginsError = nil;
    [[self clientWithVerifiedTestContext:badPlugins] requestPluginList:^(NSArray *plugins, NSError *error) { (void)plugins; badPluginsError = error; }];
    if (badPluginsError == nil) [failures addObject:@"BND1008 插件列表非法记录必须拒绝"];

    // BND1009：缺少 pluginID 在本地拒绝，不向传输发送请求。
    FKBoundaryTestTransport *missingPluginID = [self transportWithPayload:@{}];
    __block NSError *missingPluginError = nil;
    [[self clientWithVerifiedTestContext:missingPluginID] requestPluginInfo:@"" completion:^(NSDictionary *info, NSError *error) { (void)info; missingPluginError = error; }];
    if (missingPluginError == nil || missingPluginID.sendCount != 0) [failures addObject:@"BND1009 空 pluginID 必须在发送前拒绝"];

    // BND1010：插件详情请求必须使用 plugin.inspect 白名单方法。
    FKBoundaryTestTransport *inspect = [self transportWithPayload:@{@"found": @NO, @"source": @"unsupported"}];
    __block NSDictionary *inspectResult = nil;
    [[self clientWithVerifiedTestContext:inspect] requestPluginInfo:@"plugin.test" completion:^(NSDictionary *info, NSError *error) { (void)error; inspectResult = info; }];
    if (![inspect.lastMethod isEqualToString:@"plugin.inspect"] || ![inspectResult[@"found"] isEqual:@NO]) {
        [failures addObject:@"BND1010 插件详情应走 plugin.inspect 且保留 found 状态"];
    }

    // BND1011：配置快照读取必须使用 config.inspect，不提供写入方法。
    FKBoundaryTestTransport *config = [self transportWithPayload:@{@"source": @"unsupported", @"entries": @[]}];
    [[self clientWithVerifiedTestContext:config] requestConfigurationSnapshot:^(NSDictionary *snapshot, NSError *error) { (void)snapshot; (void)error; }];
    if (![config.lastMethod isEqualToString:@"config.inspect"]) [failures addObject:@"BND1011 配置读取必须使用只读 config.inspect"];

    // BND1012：disconnect 必须委托传输层关闭连接。
    FKBoundaryTestTransport *disconnect = [self transportWithPayload:@{}];
    [[self clientWithVerifiedTestContext:disconnect] disconnect];
    if (!disconnect.didDisconnect || disconnect.connected) [failures addObject:@"BND1012 disconnect 应关闭底层传输"];

    // BND1014：可信只读请求生成不含正文的 IPC 审计事件。
    FKBoundaryTestTransport *auditedTransport = [self transportWithPayload:@{@"source": @"injector_api"}];
    FKHelperReadOnlyClient *auditedClient = [self clientWithVerifiedTestContext:auditedTransport];
    __block FKHelperIPCAuditEvent *auditEvent = nil;
    auditedClient.auditEventHandler = ^(FKHelperIPCAuditEvent *event) { auditEvent = event; };
    [auditedClient requestHelperInfo:^(NSDictionary *result, NSError *error) { (void)result; (void)error; }];
    if (auditEvent == nil || auditEvent.action != FKAuditHelperIPCInfoRead ||
        ![auditEvent.source isEqualToString:@"unsupported"] ||
        ![auditEvent.buildID isEqualToString:@"FKH-0118"] ||
        ![auditEvent.sessionID isEqualToString:@"session-test-001"] ||
        auditEvent.requestID.length == 0) {
        [failures addObject:@"BND1014 只读请求审计事件字段或保守来源标记不正确"];
    }

    return failures.copy;
}
@end
