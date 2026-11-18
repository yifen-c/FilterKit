#import "FKHelperIPCCapabilities.h"

@implementation FKHelperIPCCapabilities

+ (instancetype)capabilitiesWithReadOnly:(NSArray<NSString *> *)readOnlyPermissions
                                   write:(NSArray<NSString *> *)writePermissions {
    FKHelperIPCCapabilities *capabilities = [[self alloc] init];
    capabilities.readOnlyPermissions = readOnlyPermissions ?: @[];
    capabilities.writePermissions = writePermissions ?: @[];
    return capabilities;
}

- (BOOL)containsPermission:(NSString *)permission {
    if (permission.length == 0) return NO;
    return [self.readOnlyPermissions containsObject:permission] || [self.writePermissions containsObject:permission];
}

- (BOOL)isWritePermission:(NSString *)permission {
    if (permission.length == 0) return NO;
    return [self.writePermissions containsObject:permission];
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"read_only": self.readOnlyPermissions ?: @[],
        @"write": self.writePermissions ?: @[]
    };
}

@end
