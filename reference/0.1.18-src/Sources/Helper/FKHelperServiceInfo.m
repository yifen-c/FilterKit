#import "FKHelperServiceInfo.h"

@implementation FKHelperServiceInfo

- (NSDictionary *)JSONDictionary {
    return @{
        @"identity": self.identity ? [self.identity JSONDictionary] : @{},
        @"metadata": self.metadata ? [self.metadata JSONDictionary] : @{},
        @"capabilities": self.capabilities ? [self.capabilities JSONDictionary] : @{},
        @"ready": @(self.ready)
    };
}

@end
