#import "FKHelperReadOnlyClient.h"
#import "FKHelperCapabilities.h"
#import "FKHelperMessage.h"
#import "FKHelperMessageError.h"
#import "FKHelperSession.h"
#import "FKHelperTrust.h"
#import "FKCapabilityEvaluator.h"
#import "FKHelperIPCAuditEvent.h"

@interface FKHelperReadOnlyClient ()
@property (nonatomic, strong, nullable) id<FKHelperTransport> transport;
@property (nonatomic, strong, nullable) FKHelperSession *session;
@property (nonatomic, strong, nullable) FKHelperTrustReport *trustReport;
@property (nonatomic, strong, nullable) FKHelperCapabilities *capabilities;
@property (nonatomic, strong) FKCapabilityEvaluator *capabilityEvaluator;
@end

@implementation FKHelperReadOnlyClient

- (instancetype)initWithTransport:(nullable id<FKHelperTransport>)transport {
    return [self initWithTransport:transport session:nil trustReport:nil capabilities:nil];
}

- (instancetype)initWithTransport:(nullable id<FKHelperTransport>)transport
                           session:(nullable FKHelperSession *)session
                       trustReport:(nullable FKHelperTrustReport *)trustReport
                       capabilities:(nullable FKHelperCapabilities *)capabilities {
    self = [super init];
    if (self) {
        _transport = transport;
        _session = session;
        _trustReport = trustReport;
        _capabilities = capabilities;
        _capabilityEvaluator = [FKCapabilityEvaluator new];
    }
    return self;
}

- (BOOL)connected {
    id<FKHelperTransport> transport = self.transport;
    return transport != nil && !transport.isMock && !transport.status.isMock && transport.connected;
}

- (BOOL)readyReadOnly {
    if (!self.connected || !self.session.isReadOnlyReady || self.trustReport == nil || self.capabilities == nil ||
        !self.capabilities.containsOnlyReadOnlyCapabilities || self.capabilities.supportedCapabilities.count == 0) return NO;
    for (NSString *capability in self.capabilities.supportedCapabilities) {
        if ([self.capabilityEvaluator canPerformCapability:capability
                                                trustReport:self.trustReport
                                               capabilities:self.capabilities]) return YES;
    }
    return NO;
}

- (NSError *)errorWithCode:(NSInteger)code reason:(NSString *)reason description:(NSString *)description {
    return [NSError errorWithDomain:FKHelperMessageErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description ?: reason ?: @"只读请求失败",
                                      @"reasonCode": reason ?: @"unknown"}];
}

- (FKHelperMessage *)messageForMethod:(NSString *)method payload:(NSDictionary *)payload {
    FKHelperMessage *message = [FKHelperMessage new];
    message.messageType = FKHelperMessageRequest;
    message.method = method;
    message.requestID = [NSUUID UUID].UUIDString;
    message.nonce = [NSUUID UUID].UUIDString;
    message.timestamp = [NSDate date];
    message.payload = payload ?: @{};
    return message;
}

- (FKAuditHelperIPCAction)auditActionForMethod:(NSString *)method {
    if ([method isEqualToString:@"helper.info"]) return FKAuditHelperIPCInfoRead;
    if ([method isEqualToString:@"helper.health"]) return FKAuditHelperIPCHealthRead;
    if ([method isEqualToString:@"capabilities.list"]) return FKAuditHelperIPCCapabilityFetch;
    if ([method isEqualToString:@"plugin.list"]) return FKAuditHelperIPCPluginList;
    if ([method isEqualToString:@"plugin.inspect"]) return FKAuditHelperIPCPluginInspect;
    if ([method isEqualToString:@"config.inspect"]) return FKAuditHelperIPCConfigurationRead;
    return FKAuditHelperIPCRejected;
}

- (void)emitAuditForMethod:(NSString *)method
                    result:(NSString *)result
                reasonCode:(nullable NSString *)reasonCode
               recordCount:(NSUInteger)recordCount {
    if (!self.auditEventHandler) return;
    FKHelperIPCAuditEvent *event = [FKHelperIPCAuditEvent new];
    event.source = (self.transport.isMock || self.transport.status.isMock) ? @"mock" : @"unsupported";
    event.action = [self auditActionForMethod:method];
    event.result = result ?: @"failed";
    event.helperID = self.trustReport.helperID;
    event.buildID = self.trustReport.buildID;
    event.requestID = self.session.requestID;
    event.sessionID = self.session.sessionID;
    event.reasonCode = reasonCode;
    event.recordCount = recordCount;
    self.auditEventHandler(event);
}

/// 统一发送路径：集中校验传输、请求序列化、响应关联与响应结构，避免各 API 校验不一致。
- (void)performMethod:(NSString *)method
              payload:(NSDictionary *)payload
           completion:(void (^)(NSDictionary *_Nullable result, NSError *_Nullable error))completion {
    if (!self.connected) {
        NSError *blocked = [self errorWithCode:FKHelperMessageErrorDisconnected
                                        reason:@"transport_unavailable"
                                   description:@"无非 Mock 且已连接的 Helper 传输；请求未发送"];
        [self emitAuditForMethod:method result:@"failed" reasonCode:@"transport_unavailable" recordCount:0];
        if (completion) completion(nil, blocked);
        return;
    }
    if (!self.readyReadOnly) {
        NSError *blocked = [self errorWithCode:FKHelperMessageErrorPeerUnverified
                                        reason:@"read_only_session_not_verified"
                                   description:@"传输已连接，但 Helper 会话或信任链未通过；只读请求未发送"];
        [self emitAuditForMethod:method result:@"rejected" reasonCode:@"read_only_session_not_verified" recordCount:0];
        if (completion) completion(nil, blocked);
        return;
    }
    if (![self.capabilityEvaluator canPerformCapability:method
                                             trustReport:self.trustReport
                                            capabilities:self.capabilities]) {
        NSError *blocked = [self errorWithCode:FKHelperMessageErrorUnauthorized
                                        reason:@"capability_not_available"
                                   description:@"当前会话未获得该只读 API 能力"];
        [self emitAuditForMethod:method result:@"rejected" reasonCode:@"capability_not_available" recordCount:0];
        if (completion) completion(nil, blocked);
        return;
    }

    FKHelperMessage *request = [self messageForMethod:method payload:payload];
    self.session.requestID = request.requestID;
    NSError *serializationError = nil;
    NSData *requestData = [request JSONData:&serializationError];
    if (requestData.length == 0 || serializationError != nil) {
        NSError *failure = serializationError ?: [self errorWithCode:FKHelperMessageErrorInvalidMessage
                                                              reason:@"request_serialization_failed"
                                                         description:@"只读请求无法序列化"];
        [self emitAuditForMethod:method result:@"failed" reasonCode:@"request_serialization_failed" recordCount:0];
        if (completion) completion(nil, failure);
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.transport sendData:requestData completion:^(NSData *_Nullable responseData, NSError *_Nullable transportError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) return;
        if (transportError != nil) {
            [strongSelf emitAuditForMethod:method result:@"failed" reasonCode:@"transport_error" recordCount:0];
            if (completion) completion(nil, transportError);
            return;
        }
        if (!strongSelf.readyReadOnly) {
            [strongSelf emitAuditForMethod:method result:@"rejected" reasonCode:@"session_invalidated" recordCount:0];
            if (completion) completion(nil, [strongSelf errorWithCode:FKHelperMessageErrorPeerUnverified
                                                               reason:@"session_invalidated"
                                                          description:@"请求返回前会话已失效，响应已丢弃"]);
            return;
        }

        NSError *parseError = nil;
        FKHelperMessage *response = responseData.length ? [FKHelperMessage messageFromData:responseData error:&parseError] : nil;
        if (response == nil || ![request matchesResponse:response]) {
            [strongSelf emitAuditForMethod:method result:@"failed" reasonCode:@"response_mismatch" recordCount:0];
            if (completion) completion(nil, parseError ?: [strongSelf errorWithCode:FKHelperMessageErrorInvalidMessage
                                                                               reason:@"response_mismatch"
                                                                          description:@"响应与请求的 ID、方法或协议版本不匹配"]);
            return;
        }

        if ([response.responseStatus isEqualToString:@"error"]) {
            NSDictionary *errorPayload = response.errorPayload ?: @{};
            NSString *reason = [errorPayload[@"reason"] isKindOfClass:NSString.class] ? errorPayload[@"reason"] : @"helper_request_rejected";
            NSNumber *code = [errorPayload[@"code"] isKindOfClass:NSNumber.class] ? errorPayload[@"code"] : @(FKHelperMessageErrorUnauthorized);
            [strongSelf emitAuditForMethod:method result:@"rejected" reasonCode:reason recordCount:0];
            if (completion) completion(nil, [strongSelf errorWithCode:code.integerValue reason:reason description:@"Helper 拒绝了只读请求"]);
            return;
        }

        if (![response.payload isKindOfClass:NSDictionary.class]) {
            [strongSelf emitAuditForMethod:method result:@"failed" reasonCode:@"response_payload_invalid" recordCount:0];
            if (completion) completion(nil, [strongSelf errorWithCode:FKHelperMessageErrorInvalidMessage
                                                               reason:@"response_payload_invalid"
                                                          description:@"Helper 响应载荷不是对象"]);
            return;
        }
        NSUInteger count = 0;
        if ([response.payload[@"plugins"] isKindOfClass:NSArray.class]) count = [response.payload[@"plugins"] count];
        else if ([response.payload[@"entries"] isKindOfClass:NSArray.class]) count = [response.payload[@"entries"] count];
        [strongSelf emitAuditForMethod:method result:@"success" reasonCode:nil recordCount:count];
        if (completion) completion(response.payload, nil);
    }];
}

- (void)requestHelperInfo:(void (^)(NSDictionary *_Nullable, NSError *_Nullable))completion {
    [self performMethod:@"helper.info" payload:@{} completion:completion];
}

- (void)requestHelperHealth:(void (^)(NSDictionary *_Nullable, NSError *_Nullable))completion {
    [self performMethod:@"helper.health" payload:@{} completion:completion];
}

- (void)requestCapabilities:(void (^)(FKHelperCapabilities *_Nullable, NSError *_Nullable))completion {
    [self performMethod:@"capabilities.list" payload:@{} completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (error != nil) {
            if (completion) completion(nil, error);
            return;
        }
        id raw = result[@"capabilities"];
        if (![raw isKindOfClass:NSArray.class]) {
            if (completion) completion(nil, [self errorWithCode:FKHelperMessageErrorInvalidMessage
                                                         reason:@"capability_payload_invalid"
                                                    description:@"能力响应缺少 capabilities 数组"]);
            return;
        }
        NSMutableSet<NSString *> *keys = [NSMutableSet set];
        for (id item in (NSArray *)raw) {
            if (![item isKindOfClass:NSString.class] || ![[FKHelperCapabilities readOnlyWhitelist] containsObject:item]) {
                if (completion) completion(nil, [self errorWithCode:FKHelperMessageErrorUnauthorized
                                                             reason:@"capability_not_read_only"
                                                        description:@"Helper 返回未知或非只读能力，整份能力响应已拒绝"]);
                return;
            }
            [keys addObject:item];
        }
        FKHelperCapabilities *capabilities = [FKHelperCapabilities capabilitiesWithSet:keys];
        if (!capabilities.containsOnlyReadOnlyCapabilities) {
            if (completion) completion(nil, [self errorWithCode:FKHelperMessageErrorUnauthorized
                                                         reason:@"capability_not_read_only"
                                                    description:@"能力集合包含非只读项目"]);
            return;
        }
        if (completion) completion(capabilities, nil);
    }];
}

- (void)requestPluginList:(void (^)(NSArray *_Nullable, NSError *_Nullable))completion {
    [self performMethod:@"plugin.list" payload:@{} completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (error != nil) {
            if (completion) completion(nil, error);
            return;
        }
        id plugins = result[@"plugins"];
        if (![plugins isKindOfClass:NSArray.class]) {
            if (completion) completion(nil, [self errorWithCode:FKHelperMessageErrorInvalidMessage
                                                         reason:@"plugin_list_invalid"
                                                    description:@"插件列表响应缺少 plugins 数组"]);
            return;
        }
        for (id plugin in (NSArray *)plugins) {
            if (![plugin isKindOfClass:NSDictionary.class]) {
                if (completion) completion(nil, [self errorWithCode:FKHelperMessageErrorInvalidMessage
                                                             reason:@"plugin_record_invalid"
                                                        description:@"插件列表包含非法记录"]);
                return;
            }
        }
        if (completion) completion(plugins, nil);
    }];
}

- (void)requestPluginInfo:(NSString *)pluginID
              completion:(void (^)(NSDictionary *_Nullable, NSError *_Nullable))completion {
    if (pluginID.length == 0) {
        [self emitAuditForMethod:@"plugin.inspect" result:@"rejected" reasonCode:@"plugin_id_missing" recordCount:0];
        if (completion) completion(nil, [self errorWithCode:FKHelperMessageErrorInvalidRequestID
                                                     reason:@"plugin_id_missing"
                                                description:@"插件标识不能为空"]);
        return;
    }
    [self performMethod:@"plugin.inspect" payload:@{@"pluginID": pluginID} completion:completion];
}

- (void)requestConfigurationSnapshot:(void (^)(NSDictionary *_Nullable, NSError *_Nullable))completion {
    [self performMethod:@"config.inspect" payload:@{} completion:completion];
}

- (void)disconnect {
    if (self.auditEventHandler) {
        FKHelperIPCAuditEvent *event = [FKHelperIPCAuditEvent new];
        event.source = (self.transport.isMock || self.transport.status.isMock) ? @"mock" : @"unsupported";
        event.action = FKAuditHelperIPCDisconnect;
        event.result = @"success";
        event.helperID = self.trustReport.helperID;
        event.buildID = self.trustReport.buildID;
        event.sessionID = self.session.sessionID;
        self.auditEventHandler(event);
    }
    [self.transport disconnect];
    [self.session closeSession];
}

@end
