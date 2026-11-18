#import "FKIPCResponse.h"
#import "FKHelperProtocol.h"

@implementation FKIPCResponse

+ (instancetype)responseWithRequestID:(NSString *)requestID status:(NSString *)status {
    FKIPCResponse *response = [self new];
    response.protocolVersion = FKHelperProtocolVersion;
    response.requestID = requestID ?: @"";
    response.status = status ?: @"failed";
    response.result = @{};
    response.error = @{};
    return response;
}

+ (instancetype)responseFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKIPCResponse *response = [self new];
    response.protocolVersion = [dict[@"protocol_version"] integerValue];
    response.requestID = dict[@"request_id"] ?: @"";
    response.status = dict[@"status"] ?: @"";
    response.result = [dict[@"result"] isKindOfClass:NSDictionary.class] ? dict[@"result"] : @{};
    response.error = [dict[@"error"] isKindOfClass:NSDictionary.class] ? dict[@"error"] : @{};
    return response;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"protocol_version": @(self.protocolVersion),
        @"request_id": self.requestID ?: @"",
        @"status": self.status ?: @"failed",
        @"result": self.result ?: @{},
        @"error": self.error ?: @{}
    };
}

- (BOOL)validateWithError:(NSError **)error {
    return FKHelperValidateResponse(self.JSONDictionary, error);
}

@end
