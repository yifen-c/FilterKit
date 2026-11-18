#import "FKHelperTrustManifest.h"

@implementation FKHelperArtifact

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"architecture": self.architecture ?: @"",
        @"sha256": self.sha256 ?: @"",
        @"signatureIdentity": self.signatureIdentity ?: @""
    };
}

+ (nullable instancetype)artifactFromDictionary:(nullable NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    FKHelperArtifact *artifact = [FKHelperArtifact new];
    id architecture = dictionary[@"architecture"];
    id sha256 = dictionary[@"sha256"];
    id signatureIdentity = dictionary[@"signatureIdentity"];
    artifact.architecture = [architecture isKindOfClass:NSString.class] ? architecture : @"";
    artifact.sha256 = [sha256 isKindOfClass:NSString.class] ? sha256 : @"";
    artifact.signatureIdentity = [signatureIdentity isKindOfClass:NSString.class] ? signatureIdentity : @"";
    return artifact;
}

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.architecture forKey:@"architecture"];
    [coder encodeObject:self.sha256 forKey:@"sha256"];
    [coder encodeObject:self.signatureIdentity forKey:@"signatureIdentity"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _architecture = [coder decodeObjectOfClass:NSString.class forKey:@"architecture"] ?: @"";
        _sha256 = [coder decodeObjectOfClass:NSString.class forKey:@"sha256"] ?: @"";
        _signatureIdentity = [coder decodeObjectOfClass:NSString.class forKey:@"signatureIdentity"] ?: @"";
    }
    return self;
}

@end

@implementation FKHelperTrustManifest

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (BOOL)isValidSHA256Hex:(NSString *)value {
    if (![value isKindOfClass:NSString.class] || value.length != 64) {
        return NO;
    }
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    return [value rangeOfCharacterFromSet:hex.invertedSet].location == NSNotFound;
}

- (BOOL)isStructurallyValid {
    if (self.helperID.length == 0 ||
        self.productID.length == 0 ||
        self.componentID.length == 0 ||
        self.version.length == 0 ||
        self.buildID.length == 0) {
        return NO;
    }
    if (self.protocolMajor < 1) {
        return NO;
    }
    return YES;
}

- (BOOL)hasTrustedArtifacts {
    for (FKHelperArtifact *artifact in self.artifacts) {
        if ([FKHelperTrustManifest isValidSHA256Hex:artifact.sha256]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isDevelopmentRelease {
    return ![self.releaseStatus isEqualToString:@"release"];
}

- (nullable FKHelperArtifact *)artifactForArchitecture:(NSString *)architecture {
    if (architecture.length == 0) {
        return nil;
    }
    for (FKHelperArtifact *artifact in self.artifacts) {
        if ([artifact.architecture isEqualToString:architecture]) {
            return artifact;
        }
    }
    return nil;
}

- (NSDictionary *)JSONDictionary {
    NSMutableArray<NSDictionary *> *artifactJSON = [NSMutableArray array];
    for (FKHelperArtifact *artifact in self.artifacts) {
        [artifactJSON addObject:artifact.JSONDictionary];
    }
    return @{
        @"schemaVersion": @(self.schemaVersion),
        @"helperID": self.helperID ?: @"",
        @"productID": self.productID ?: @"",
        @"componentID": self.componentID ?: @"",
        @"version": self.version ?: @"",
        @"buildID": self.buildID ?: @"",
        @"protocolMajor": @(self.protocolMajor),
        @"protocolMinor": @(self.protocolMinor),
        @"artifacts": artifactJSON.copy,
        @"manifestKeyID": self.manifestKeyID ?: @"",
        @"releaseStatus": self.releaseStatus ?: @"development"
    };
}

+ (nullable instancetype)manifestFromDictionary:(nullable NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    FKHelperTrustManifest *manifest = [FKHelperTrustManifest new];

    id release = dictionary[@"release"];
    id protocol = dictionary[@"protocol"];
    id trust = dictionary[@"trust"];

    id version = dictionary[@"version"] ?: ([release isKindOfClass:NSDictionary.class] ? release[@"version"] : nil);
    id buildID = dictionary[@"buildID"] ?: ([release isKindOfClass:NSDictionary.class] ? release[@"buildID"] : nil);
    id channel = dictionary[@"releaseStatus"] ?: ([release isKindOfClass:NSDictionary.class] ? release[@"channel"] : nil);
    id protocolMajor = [protocol isKindOfClass:NSDictionary.class] ? protocol[@"major"] : dictionary[@"protocolMajor"];
    id protocolMinor = [protocol isKindOfClass:NSDictionary.class] ? protocol[@"minor"] : dictionary[@"protocolMinor"];
    id manifestKeyID = dictionary[@"manifestKeyID"] ?: ([trust isKindOfClass:NSDictionary.class] ? trust[@"manifestKeyID"] : nil);

    manifest.helperID = [dictionary[@"helperID"] isKindOfClass:NSString.class] ? dictionary[@"helperID"] : @"";
    manifest.productID = [dictionary[@"product"] isKindOfClass:NSString.class] ? dictionary[@"product"]
                        : ([dictionary[@"productID"] isKindOfClass:NSString.class] ? dictionary[@"productID"] : @"");
    manifest.componentID = [dictionary[@"component"] isKindOfClass:NSString.class] ? dictionary[@"component"]
                        : ([dictionary[@"componentID"] isKindOfClass:NSString.class] ? dictionary[@"componentID"] : @"");
    manifest.version = [version isKindOfClass:NSString.class] ? version : @"";
    manifest.buildID = [buildID isKindOfClass:NSString.class] ? buildID : @"";
    manifest.releaseStatus = [channel isKindOfClass:NSString.class] && ((NSString *)channel).length > 0 ? channel : @"development";
    manifest.manifestKeyID = [manifestKeyID isKindOfClass:NSString.class] ? manifestKeyID : nil;

    if ([protocolMajor isKindOfClass:NSNumber.class]) {
        manifest.protocolMajor = [((NSNumber *)protocolMajor) integerValue];
    }
    if ([protocolMinor isKindOfClass:NSNumber.class]) {
        manifest.protocolMinor = [((NSNumber *)protocolMinor) integerValue];
    }
    id schema = dictionary[@"schemaVersion"];
    if ([schema isKindOfClass:NSNumber.class]) {
        manifest.schemaVersion = [((NSNumber *)schema) integerValue];
    }

    NSMutableArray<FKHelperArtifact *> *artifacts = [NSMutableArray array];
    id artifactList = dictionary[@"artifacts"];
    if ([artifactList isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)artifactList) {
            FKHelperArtifact *artifact = [FKHelperArtifact artifactFromDictionary:item];
            if (artifact) {
                [artifacts addObject:artifact];
            }
        }
    }
    manifest.artifacts = artifacts.copy;
    return manifest;
}

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.schemaVersion forKey:@"schemaVersion"];
    [coder encodeObject:self.helperID forKey:@"helperID"];
    [coder encodeObject:self.productID forKey:@"productID"];
    [coder encodeObject:self.componentID forKey:@"componentID"];
    [coder encodeObject:self.version forKey:@"version"];
    [coder encodeObject:self.buildID forKey:@"buildID"];
    [coder encodeInteger:self.protocolMajor forKey:@"protocolMajor"];
    [coder encodeInteger:self.protocolMinor forKey:@"protocolMinor"];
    [coder encodeObject:self.artifacts forKey:@"artifacts"];
    [coder encodeObject:self.manifestKeyID forKey:@"manifestKeyID"];
    [coder encodeObject:self.releaseStatus forKey:@"releaseStatus"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _schemaVersion = [coder decodeIntegerForKey:@"schemaVersion"];
        _helperID = [coder decodeObjectOfClass:NSString.class forKey:@"helperID"] ?: @"";
        _productID = [coder decodeObjectOfClass:NSString.class forKey:@"productID"] ?: @"";
        _componentID = [coder decodeObjectOfClass:NSString.class forKey:@"componentID"] ?: @"";
        _version = [coder decodeObjectOfClass:NSString.class forKey:@"version"] ?: @"";
        _buildID = [coder decodeObjectOfClass:NSString.class forKey:@"buildID"] ?: @"";
        _protocolMajor = [coder decodeIntegerForKey:@"protocolMajor"];
        _protocolMinor = [coder decodeIntegerForKey:@"protocolMinor"];
        NSArray *artifacts = [coder decodeObjectOfClass:NSArray.class forKey:@"artifacts"];
        _artifacts = [artifacts isKindOfClass:NSArray.class] ? artifacts : @[];
        _manifestKeyID = [coder decodeObjectOfClass:NSString.class forKey:@"manifestKeyID"];
        _releaseStatus = [coder decodeObjectOfClass:NSString.class forKey:@"releaseStatus"] ?: @"development";
    }
    return self;
}

@end
