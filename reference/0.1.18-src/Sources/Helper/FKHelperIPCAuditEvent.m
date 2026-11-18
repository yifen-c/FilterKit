#import "FKHelperIPCAuditEvent.h"

@implementation FKHelperIPCAuditEvent

- (instancetype)init {
    self = [super init];
    if (self) {
        _eventID = [[NSUUID UUID] UUIDString];
        _timestamp = [NSDate date];
        _source = @"unsupported";
        _result = @"failed";
        _recordCount = 0;
    }
    return self;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"eventID": self.eventID ?: @"",
        @"timestamp": @([self.timestamp timeIntervalSince1970]),
        @"source": self.source ?: @"unsupported",
        @"action": [FKHelperIPCAuditEvent actionCode:self.action],
        @"result": self.result ?: @"failed",
        @"helperID": self.helperID ?: @"",
        @"buildID": self.buildID ?: @"",
        @"requestID": self.requestID ?: @"",
        @"sessionID": self.sessionID ?: @"",
        @"reasonCode": self.reasonCode ?: [NSNull null],
        @"recordCount": @(self.recordCount)
    };
}


+ (nullable instancetype)eventFromDictionary:(nullable NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) return nil;
    FKHelperIPCAuditEvent *event = [FKHelperIPCAuditEvent new];
    id eventID = dictionary[@"eventID"];
    id timestamp = dictionary[@"timestamp"];
    id source = dictionary[@"source"];
    id action = dictionary[@"action"];
    id result = dictionary[@"result"];
    id helperID = dictionary[@"helperID"];
    id buildID = dictionary[@"buildID"];
    id requestID = dictionary[@"requestID"];
    id sessionID = dictionary[@"sessionID"];
    id reasonCode = dictionary[@"reasonCode"];
    id recordCount = dictionary[@"recordCount"];

    if (![eventID isKindOfClass:NSString.class] || [eventID length] == 0 ||
        ![timestamp isKindOfClass:NSNumber.class] ||
        ![source isKindOfClass:NSString.class] ||
        ![action isKindOfClass:NSString.class] ||
        ![result isKindOfClass:NSString.class]) return nil;

    NSDictionary<NSString *, NSNumber *> *actions = @{
        @"connect": @(FKAuditHelperIPCConnect),
        @"disconnect": @(FKAuditHelperIPCDisconnect),
        @"handshake": @(FKAuditHelperIPCHandshake),
        @"peer_verify": @(FKAuditHelperIPCPeerVerify),
        @"capability_fetch": @(FKAuditHelperIPCCapabilityFetch),
        @"plugin_list": @(FKAuditHelperIPCPluginList),
        @"plugin_inspect": @(FKAuditHelperIPCPluginInspect),
        @"configuration_read": @(FKAuditHelperIPCConfigurationRead),
        @"rejected": @(FKAuditHelperIPCRejected),
        @"helper_info_read": @(FKAuditHelperIPCInfoRead),
        @"helper_health_read": @(FKAuditHelperIPCHealthRead),
        @"peer_binding": @(FKAuditHelperIPCPeerBinding),
        @"key_confirmation": @(FKAuditHelperIPCKeyConfirmation),
        @"handshake_state": @(FKAuditHelperIPCHandshakeState),
        @"session_expired": @(FKAuditHelperIPCSessionExpired)
    };
    NSNumber *actionValue = actions[action];
    if (actionValue == nil) return nil;

    event.eventID = eventID;
    event.timestamp = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
    NSSet *validSources = [NSSet setWithArray:@[@"real_ipc", @"mock", @"unsupported"]];
    event.source = [validSources containsObject:source] ? source : @"unsupported";
    event.action = (FKAuditHelperIPCAction)actionValue.integerValue;
    event.result = [@[@"success", @"failed", @"rejected"] containsObject:result] ? result : @"failed";
    event.helperID = [helperID isKindOfClass:NSString.class] ? helperID : nil;
    event.buildID = [buildID isKindOfClass:NSString.class] ? buildID : nil;
    event.requestID = [requestID isKindOfClass:NSString.class] ? requestID : nil;
    event.sessionID = [sessionID isKindOfClass:NSString.class] ? sessionID : nil;
    event.reasonCode = [reasonCode isKindOfClass:NSString.class] ? reasonCode : nil;
    event.recordCount = [recordCount isKindOfClass:NSNumber.class] ? [recordCount unsignedIntegerValue] : 0;
    return event;
}

+ (NSString *)actionCode:(FKAuditHelperIPCAction)action {
    switch (action) {
        case FKAuditHelperIPCDisconnect:          return @"disconnect";
        case FKAuditHelperIPCHandshake:           return @"handshake";
        case FKAuditHelperIPCPeerVerify:         return @"peer_verify";
        case FKAuditHelperIPCCapabilityFetch:     return @"capability_fetch";
        case FKAuditHelperIPCPluginList:          return @"plugin_list";
        case FKAuditHelperIPCPluginInspect:       return @"plugin_inspect";
        case FKAuditHelperIPCConfigurationRead:    return @"configuration_read";
        case FKAuditHelperIPCRejected:            return @"rejected";
        case FKAuditHelperIPCInfoRead:             return @"helper_info_read";
        case FKAuditHelperIPCHealthRead:           return @"helper_health_read";
        case FKAuditHelperIPCPeerBinding:          return @"peer_binding";
        case FKAuditHelperIPCKeyConfirmation:      return @"key_confirmation";
        case FKAuditHelperIPCHandshakeState:       return @"handshake_state";
        case FKAuditHelperIPCSessionExpired:       return @"session_expired";
        case FKAuditHelperIPCConnect:
        default:                                  return @"connect";
    }
}

+ (NSString *)actionText:(FKAuditHelperIPCAction)action {
    switch (action) {
        case FKAuditHelperIPCDisconnect:          return @"断开连接";
        case FKAuditHelperIPCHandshake:           return @"握手协商";
        case FKAuditHelperIPCPeerVerify:         return @"对端验证";
        case FKAuditHelperIPCCapabilityFetch:     return @"能力获取";
        case FKAuditHelperIPCPluginList:          return @"插件列表读取";
        case FKAuditHelperIPCPluginInspect:       return @"插件详情读取";
        case FKAuditHelperIPCConfigurationRead:    return @"配置读取";
        case FKAuditHelperIPCRejected:            return @"请求被拒绝";
        case FKAuditHelperIPCInfoRead:             return @"Helper 信息读取";
        case FKAuditHelperIPCHealthRead:           return @"Helper 健康状态读取";
        case FKAuditHelperIPCPeerBinding:          return @"Peer 身份绑定";
        case FKAuditHelperIPCKeyConfirmation:      return @"双向密钥确认";
        case FKAuditHelperIPCHandshakeState:       return @"握手状态转换";
        case FKAuditHelperIPCSessionExpired:       return @"会话过期";
        case FKAuditHelperIPCConnect:
        default:                                  return @"建立连接";
    }
}

@end
