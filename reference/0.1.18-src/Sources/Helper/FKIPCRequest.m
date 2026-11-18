#import "FKIPCRequest.h"
#import "FKHelperProtocol.h"

@implementation FKIPCRequest

+ (instancetype)requestWithPluginID:(NSString *)pluginID operation:(NSString *)operation {
    FKIPCRequest *request = [self new];
    request.protocolVersion = FKHelperProtocolVersion;
    request.requestID = [[NSUUID UUID] UUIDString];
    request.operation = operation ?: @"";
    request.pluginID = pluginID ?: @"";
    request.timestamp = [[NSDate date] timeIntervalSince1970];
    request.nonce = [[NSUUID UUID] UUIDString];
    request.authorization = @"";
    return request;
}

+ (instancetype)requestFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKIPCRequest *request = [self new];
    request.protocolVersion = [dict[@"protocol_version"] integerValue];
    request.requestID = dict[@"request_id"] ?: @"";
    request.operation = dict[@"operation"] ?: @"";
    request.pluginID = dict[@"plugin_id"] ?: @"";
    request.timestamp = [dict[@"timestamp"] doubleValue];
    request.nonce = dict[@"nonce"] ?: @"";
    request.authorization = dict[@"authorization"] ?: @"";
    return request;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"protocol_version": @(self.protocolVersion),
        @"request_id": self.requestID ?: @"",
        @"operation": self.operation ?: @"",
        @"plugin_id": self.pluginID ?: @"",
        @"timestamp": @(self.timestamp),
        @"nonce": self.nonce ?: @"",
        @"authorization": self.authorization ?: @""
    };
}

- (BOOL)validateWithError:(NSError **)error {
    return FKHelperValidateRequest(self.JSONDictionary, error);
}

@end
