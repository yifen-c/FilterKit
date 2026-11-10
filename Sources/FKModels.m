#import "FKModels.h"

@implementation FKTestResult

+ (instancetype)resultWithID:(NSString *)identifier title:(NSString *)title state:(FKTestState)state detail:(NSString *)detail payload:(NSDictionary *)payload {
    FKTestResult *item = [FKTestResult new];
    item.identifier = identifier ?: @"";
    item.title = title ?: @"";
    item.state = state;
    item.detail = detail ?: @"";
    item.payload = payload ?: @{};
    return item;
}

- (NSDictionary *)JSONDictionary {
    NSString *state = self.state == FKTestStatePassed ? @"passed" : (self.state == FKTestStateFailed ? @"failed" : @"unknown");
    return @{
        @"id": self.identifier,
        @"title": self.title,
        @"state": state,
        @"detail": self.detail,
        @"payload": self.payload ?: @{}
    };
}

@end
