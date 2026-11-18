#import "FKHelperTransportState.h"

NSErrorDomain const FKHelperTransportErrorDomain = @"com.filterkit.helper.transport";

@implementation FKHelperTransportStatus

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = FKHelperTransportStateIdle;
        _timestamp = [NSDate date];
        _isMock = NO;
    }
    return self;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"state": @(self.state),
        @"isMock": @(self.isMock),
        @"timestamp": @(self.timestamp ? [self.timestamp timeIntervalSince1970] : 0),
        @"error": self.error.localizedDescription ?: @""
    };
}

@end
