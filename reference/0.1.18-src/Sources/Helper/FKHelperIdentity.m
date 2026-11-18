#import "FKHelperIdentity.h"

@implementation FKHelperIdentity

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)expectedIdentity {
    FKHelperIdentity *identity = [FKHelperIdentity new];
    identity.helperID = @"com.filterkit.helper";
    identity.productID = @"FilterKit";
    identity.componentID = @"FilterKitHelper";
    identity.version = @"0.1.18";
    identity.buildID = @"FKH-0118";
    identity.protocolMajor = 1;
    identity.protocolMinor = 0;
    return identity;
}

- (BOOL)isStructurallyValid {
    if (self.helperID.length == 0 ||
        self.productID.length == 0 ||
        self.componentID.length == 0 ||
        self.version.length == 0 ||
        self.buildID.length == 0) {
        return NO;
    }
    if (self.protocolMajor < 1 || self.protocolMinor < 0) {
        return NO;
    }
    return YES;
}

- (BOOL)matchesIdentity:(nullable FKHelperIdentity *)other {
    if (other == nil) {
        return NO;
    }
    return [self.helperID isEqualToString:other.helperID] &&
           [self.productID isEqualToString:other.productID] &&
           [self.componentID isEqualToString:other.componentID] &&
           [self.version isEqualToString:other.version] &&
           [self.buildID isEqualToString:other.buildID] &&
           self.protocolMajor == other.protocolMajor &&
           self.protocolMinor == other.protocolMinor;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"helperID": self.helperID ?: @"",
        @"productID": self.productID ?: @"",
        @"componentID": self.componentID ?: @"",
        @"version": self.version ?: @"",
        @"buildID": self.buildID ?: @"",
        @"protocolMajor": @(self.protocolMajor),
        @"protocolMinor": @(self.protocolMinor)
    };
}

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.helperID forKey:@"helperID"];
    [coder encodeObject:self.productID forKey:@"productID"];
    [coder encodeObject:self.componentID forKey:@"componentID"];
    [coder encodeObject:self.version forKey:@"version"];
    [coder encodeObject:self.buildID forKey:@"buildID"];
    [coder encodeInteger:self.protocolMajor forKey:@"protocolMajor"];
    [coder encodeInteger:self.protocolMinor forKey:@"protocolMinor"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _helperID = [coder decodeObjectOfClass:NSString.class forKey:@"helperID"] ?: @"";
        _productID = [coder decodeObjectOfClass:NSString.class forKey:@"productID"] ?: @"";
        _componentID = [coder decodeObjectOfClass:NSString.class forKey:@"componentID"] ?: @"";
        _version = [coder decodeObjectOfClass:NSString.class forKey:@"version"] ?: @"";
        _buildID = [coder decodeObjectOfClass:NSString.class forKey:@"buildID"] ?: @"";
        _protocolMajor = [coder decodeIntegerForKey:@"protocolMajor"];
        _protocolMinor = [coder decodeIntegerForKey:@"protocolMinor"];
    }
    return self;
}

@end
