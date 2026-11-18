#import "FKHelperIPCHandshake.h"
#import "FKHelperProtocol.h"

@implementation FKHelperIPCHandshakeRequest

+ (instancetype)requestWithClientVersion:(NSString *)clientVersion protocolVersion:(NSInteger)protocolVersion {
    FKHelperIPCHandshakeRequest *request = [self new];
    request.client = @"FilterKit";
    request.clientVersion = clientVersion ?: @"";
    request.protocolVersion = protocolVersion;
    request.request = @"capabilities";
    return request;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"type": @"handshake",
        @"client": self.client ?: @"",
        @"client_version": self.clientVersion ?: @"",
        @"protocol_version": @(self.protocolVersion),
        @"request": self.request ?: @""
    };
}

@end

@implementation FKHelperIPCHandshakeResponse

+ (nullable instancetype)responseFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKHelperIPCHandshakeResponse *response = [self new];
    response.helperID = dict[@"helper_id"] ?: @"";
    response.helperVersion = dict[@"helper_version"] ?: @"";
    response.protocolVersion = [dict[@"protocol_version"] integerValue];
    response.status = dict[@"status"] ?: @"";
    NSArray *capabilities = dict[@"capabilities"];
    response.capabilities = [capabilities isKindOfClass:NSArray.class] ? capabilities : @[];
    return response;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"type": @"handshake_response",
        @"helper_id": self.helperID ?: @"",
        @"helper_version": self.helperVersion ?: @"",
        @"protocol_version": @(self.protocolVersion),
        @"status": self.status ?: @"",
        @"capabilities": self.capabilities ?: @[]
    };
}

- (BOOL)validateWithError:(NSError **)error {
    if (self.protocolVersion != FKHelperProtocolVersion) {
        if (error) *error = [NSError errorWithDomain:FKHelperErrorDomain code:FKHelperErrorIncompatible
                                            userInfo:@{NSLocalizedDescriptionKey: @"握手响应协议版本不兼容"}];
        return NO;
    }
    if (self.status.length == 0) {
        if (error) *error = [NSError errorWithDomain:FKHelperErrorDomain code:FKHelperErrorInvalidRequest
                                            userInfo:@{NSLocalizedDescriptionKey: @"握手响应缺少状态字段"}];
        return NO;
    }
    if (self.helperID.length == 0) {
        if (error) *error = [NSError errorWithDomain:FKHelperErrorDomain code:FKHelperErrorUnauthorized
                                            userInfo:@{NSLocalizedDescriptionKey: @"握手响应缺少对端身份标识"}];
        return NO;
    }
    return YES;
}

@end

@implementation FKHelperIPCHandshake

+ (NSString *)statusCodeForStatus:(FKHelperIPCStatus)status {
    switch (status) {
        case FKHelperIPCUnavailable: return @"UNAVAILABLE";
        case FKHelperIPCDisconnected: return @"DISCONNECTED";
        case FKHelperIPCConnecting: return @"CONNECTING";
        case FKHelperIPCConnected: return @"CONNECTED";
        case FKHelperIPCHandshakeFailed: return @"HANDSHAKE_FAILED";
        case FKHelperIPCIncompatible: return @"INCOMPATIBLE";
        case FKHelperIPCPeerUnverified: return @"PEER_UNVERIFIED";
    }
    return @"UNKNOWN";
}

+ (NSString *)statusTextForStatus:(FKHelperIPCStatus)status {
    switch (status) {
        case FKHelperIPCUnavailable: return @"不可用";
        case FKHelperIPCDisconnected: return @"已断开";
        case FKHelperIPCConnecting: return @"连接中";
        case FKHelperIPCConnected: return @"已连接";
        case FKHelperIPCHandshakeFailed: return @"握手失败";
        case FKHelperIPCIncompatible: return @"协议不兼容";
        case FKHelperIPCPeerUnverified: return @"对端未验证";
    }
    return @"未知";
}

@end
