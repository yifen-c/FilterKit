#import "FKHelperHandshake.h"

@implementation FKHelperHandshake

- (instancetype)init {
    self = [super init];
    if (self) {
        _clientProtocolMajor = 1;
        _clientProtocolMinor = 0;
        _status = FKHelperHandshakeStatusIdle;
        _timestamp = [NSDate date];
    }
    return self;
}

- (BOOL)isProtocolCompatibleWithMajor:(NSInteger)major minor:(NSInteger)minor {
    (void)minor;
    return major == self.clientProtocolMajor;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"clientProtocolMajor": @(self.clientProtocolMajor),
        @"clientProtocolMinor": @(self.clientProtocolMinor),
        @"peerHelperID": self.peerHelperID ?: @"",
        @"status": @(self.status),
        @"nonce": self.nonce ?: @"",
        @"timestamp": @(self.timestamp ? [self.timestamp timeIntervalSince1970] : 0)
    };
}

@end
