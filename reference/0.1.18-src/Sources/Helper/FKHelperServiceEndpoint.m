#import "FKHelperServiceEndpoint.h"

@implementation FKHelperServiceEndpoint

- (instancetype)initWithServiceName:(NSString *)serviceName
                            helperID:(nullable NSString *)helperID
                              status:(FKHelperDiscoveryStatus)status
                              source:(NSString *)source
                          reasonCode:(nullable NSString *)reasonCode {
    self = [super init];
    if (self) {
        _serviceName = serviceName ?: @"";
        _helperID = helperID;
        _status = status;
        _source = source ?: @"unknown";
        _reasonCode = reasonCode;
    }
    return self;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"serviceName": self.serviceName,
        @"helperID": self.helperID ?: @"",
        @"status": [FKHelperDiscovery statusCodeForStatus:self.status],
        @"statusText": [FKHelperDiscovery statusTextForStatus:self.status],
        @"source": self.source,
        @"reasonCode": self.reasonCode ?: @""
    };
}

@end
