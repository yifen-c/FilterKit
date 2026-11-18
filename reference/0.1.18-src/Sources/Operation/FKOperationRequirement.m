#import "FKOperationRequirement.h"

@implementation FKOperationRequirement

+ (instancetype)requirementWithID:(NSString *)identifier
                              title:(NSString *)title
                            required:(BOOL)required
                             summary:(NSString *)summary {
    FKOperationRequirement *req = [self new];
    req.requirementID = identifier ?: @"";
    req.title = title ?: @"";
    req.required = required;
    req.summary = summary ?: @"";
    return req;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"id": self.requirementID ?: @"",
        @"title": self.title ?: @"",
        @"required": @(self.required),
        @"summary": self.summary ?: @""
    };
}

@end
