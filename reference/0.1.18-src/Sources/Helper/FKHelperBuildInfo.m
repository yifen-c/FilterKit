#import "FKHelperBuildInfo.h"

@implementation FKHelperBuildInfo

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"productVersion": self.productVersion ?: @"",
        @"buildNumber": self.buildNumber ?: @"",
        @"sdkVersion": self.sdkVersion ?: @"",
        @"minimumOSVersion": self.minimumOSVersion ?: @"",
        @"architectures": self.architectures ?: @[],
        @"sourceRevision": self.sourceRevision ?: @""
    };
}

+ (nullable instancetype)buildInfoFromDictionary:(nullable NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    FKHelperBuildInfo *info = [FKHelperBuildInfo new];
    id productVersion = dictionary[@"productVersion"];
    id buildNumber = dictionary[@"buildNumber"];
    id sdkVersion = dictionary[@"sdkVersion"];
    id minimumOSVersion = dictionary[@"minimumOSVersion"];
    id sourceRevision = dictionary[@"sourceRevision"];
    id architectures = dictionary[@"architectures"];

    info.productVersion = [productVersion isKindOfClass:NSString.class] ? productVersion : @"";
    info.buildNumber = [buildNumber isKindOfClass:NSString.class] ? buildNumber : @"";
    info.sdkVersion = [sdkVersion isKindOfClass:NSString.class] ? sdkVersion : @"";
    info.minimumOSVersion = [minimumOSVersion isKindOfClass:NSString.class] ? minimumOSVersion : @"";
    info.sourceRevision = [sourceRevision isKindOfClass:NSString.class] ? sourceRevision : @"";

    NSMutableArray<NSString *> *archs = [NSMutableArray array];
    if ([architectures isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)architectures) {
            if ([item isKindOfClass:NSString.class]) {
                [archs addObject:(NSString *)item];
            }
        }
    }
    info.architectures = archs.copy;
    return info;
}

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.productVersion forKey:@"productVersion"];
    [coder encodeObject:self.buildNumber forKey:@"buildNumber"];
    [coder encodeObject:self.sdkVersion forKey:@"sdkVersion"];
    [coder encodeObject:self.minimumOSVersion forKey:@"minimumOSVersion"];
    [coder encodeObject:self.architectures forKey:@"architectures"];
    [coder encodeObject:self.sourceRevision forKey:@"sourceRevision"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _productVersion = [coder decodeObjectOfClass:NSString.class forKey:@"productVersion"] ?: @"";
        _buildNumber = [coder decodeObjectOfClass:NSString.class forKey:@"buildNumber"] ?: @"";
        _sdkVersion = [coder decodeObjectOfClass:NSString.class forKey:@"sdkVersion"] ?: @"";
        _minimumOSVersion = [coder decodeObjectOfClass:NSString.class forKey:@"minimumOSVersion"] ?: @"";
        NSArray *archs = [coder decodeObjectOfClass:NSArray.class forKey:@"architectures"];
        if ([archs isKindOfClass:NSArray.class]) {
            NSMutableArray<NSString *> *filtered = [NSMutableArray array];
            for (id item in archs) {
                if ([item isKindOfClass:NSString.class]) {
                    [filtered addObject:(NSString *)item];
                }
            }
            _architectures = filtered.copy;
        } else {
            _architectures = @[];
        }
        _sourceRevision = [coder decodeObjectOfClass:NSString.class forKey:@"sourceRevision"] ?: @"";
    }
    return self;
}

@end
