#import "FKInjectorCompatibility.h"

@implementation FKInjectorCompatibility

+ (NSString *)statusCode:(FKInjectorCompatibilityStatus)status {
    switch (status) {
        case FKInjectorCompatibilityStatusCompatible: return @"compatible";
        case FKInjectorCompatibilityStatusPartial: return @"partial";
        case FKInjectorCompatibilityStatusIncompatible: return @"incompatible";
        case FKInjectorCompatibilityStatusUnknown:
        default: return @"unknown";
    }
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"plugin_id": self.pluginID ?: @"",
        @"injector_id": self.injectorID ?: @"unknown",
        @"status": [FKInjectorCompatibility statusCode:self.status],
        @"reasons": self.reasons ?: @[]
    };
}

@end
