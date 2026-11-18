#import "FKHelperCapabilities.h"

@implementation FKHelperCapabilities

+ (NSSet<NSString *> *)readOnlyWhitelist {
    static NSSet<NSString *> *whitelist;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        whitelist = [NSSet setWithArray:@[
            @"helper.info",
            @"helper.health",
            @"capabilities.list",
            @"plugin.list",
            @"plugin.inspect",
            @"config.inspect"
        ]];
    });
    return whitelist;
}

+ (NSString *)keyForCapability:(FKHelperCapability)capability {
    switch (capability) {
        case FKHelperCapabilityHelperHealth:            return @"helper.health";
        case FKHelperCapabilityCapabilityList:          return @"capabilities.list";
        case FKHelperCapabilityPluginList:              return @"plugin.list";
        case FKHelperCapabilityPluginInspect:           return @"plugin.inspect";
        case FKHelperCapabilityConfigurationInspect:   return @"config.inspect";
        case FKHelperCapabilityHelperInfo:
        default:                                        return @"helper.info";
    }
}

+ (NSSet<NSString *> *)writeCapabilityBlacklist {
    static NSSet<NSString *> *blacklist;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blacklist = [NSSet setWithArray:@[
            @"plugin.enable",
            @"plugin.disable",
            @"plugin.delete",
            @"config.write",
            @"filter.modify",
            @"file.restore"
        ]];
    });
    return blacklist;
}

+ (instancetype)capabilitiesWithSet:(NSSet<NSString *> *)capabilities {
    FKHelperCapabilities *model = [FKHelperCapabilities new];
    model.supportedCapabilities = capabilities ?: [NSSet set];
    return model;
}

- (BOOL)supportsCapability:(NSString *)capability {
    if (capability.length == 0) {
        return NO;
    }
    return [[FKHelperCapabilities readOnlyWhitelist] containsObject:capability] &&
           [self.supportedCapabilities containsObject:capability];
}

- (BOOL)containsOnlyReadOnlyCapabilities {
    return [self.supportedCapabilities isSubsetOfSet:[FKHelperCapabilities readOnlyWhitelist]];
}

- (NSDictionary *)JSONDictionary {
    NSArray<NSString *> *sorted = [self.supportedCapabilities.allObjects sortedArrayUsingSelector:@selector(compare:)];
    return @{
        @"supportedCapabilities": sorted,
        @"readOnlyOnly": @(self.containsOnlyReadOnlyCapabilities)
    };
}

@end
