#import "FKHelperReleaseMetadata.h"

@implementation FKHelperReleaseMetadata

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (BOOL)isComplete {
    if (self.helperID.length == 0 ||
        self.version.length == 0 ||
        self.buildID.length == 0 ||
        self.protocolVersion.length == 0 ||
        self.architecture.length == 0) {
        return NO;
    }
    if (self.binarySize == 0 || self.binarySHA256.length == 0) {
        return NO;
    }
    return YES;
}

- (NSDictionary *)JSONDictionary {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"helperID"] = self.helperID ?: @"";
    json[@"version"] = self.version ?: @"";
    json[@"buildID"] = self.buildID ?: @"";
    json[@"protocolVersion"] = self.protocolVersion ?: @"";
    json[@"architecture"] = self.architecture ?: @"";
    json[@"binarySize"] = @(self.binarySize);
    json[@"binarySHA256"] = self.binarySHA256 ?: @"";
    json[@"source"] = self.source ?: @"unknown";
    json[@"signatureStatus"] = self.signatureStatus ?: @"unknown";
    if (self.buildDate) {
        json[@"buildDate"] = [formatter stringFromDate:self.buildDate];
    } else {
        json[@"buildDate"] = @"";
    }
    return json.copy;
}

+ (nullable instancetype)metadataFromDictionary:(nullable NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    FKHelperReleaseMetadata *metadata = [FKHelperReleaseMetadata new];
    id helperID = dictionary[@"helperID"];
    id version = dictionary[@"version"];
    id buildID = dictionary[@"buildID"];
    id protocolVersion = dictionary[@"protocolVersion"];
    id architecture = dictionary[@"architecture"];
    id source = dictionary[@"source"];
    id signatureStatus = dictionary[@"signatureStatus"];
    id binarySHA256 = dictionary[@"binarySHA256"];

    metadata.helperID = [helperID isKindOfClass:NSString.class] ? helperID : @"";
    metadata.version = [version isKindOfClass:NSString.class] ? version : @"";
    metadata.buildID = [buildID isKindOfClass:NSString.class] ? buildID : @"";
    metadata.protocolVersion = [protocolVersion isKindOfClass:NSString.class] ? protocolVersion : @"";
    metadata.architecture = [architecture isKindOfClass:NSString.class] ? architecture : @"";
    metadata.source = [source isKindOfClass:NSString.class] ? source : @"unknown";
    metadata.signatureStatus = [signatureStatus isKindOfClass:NSString.class] ? signatureStatus : @"unknown";
    metadata.binarySHA256 = [binarySHA256 isKindOfClass:NSString.class] ? binarySHA256 : @"";

    id sizeValue = dictionary[@"binarySize"];
    if ([sizeValue isKindOfClass:NSNumber.class]) {
        metadata.binarySize = [((NSNumber *)sizeValue) unsignedLongLongValue];
    } else if ([sizeValue isKindOfClass:NSString.class]) {
        metadata.binarySize = ((NSString *)sizeValue).longLongValue > 0 ? ((NSString *)sizeValue).longLongValue : 0;
    }

    id dateValue = dictionary[@"buildDate"];
    if ([dateValue isKindOfClass:NSDate.class]) {
        metadata.buildDate = dateValue;
    } else if ([dateValue isKindOfClass:NSString.class] && ((NSString *)dateValue).length > 0) {
        NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
        metadata.buildDate = [formatter dateFromString:(NSString *)dateValue];
    }
    return metadata;
}

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.helperID forKey:@"helperID"];
    [coder encodeObject:self.version forKey:@"version"];
    [coder encodeObject:self.buildID forKey:@"buildID"];
    [coder encodeObject:self.protocolVersion forKey:@"protocolVersion"];
    [coder encodeObject:self.architecture forKey:@"architecture"];
    [coder encodeObject:@(self.binarySize) forKey:@"binarySize"];
    [coder encodeObject:self.binarySHA256 forKey:@"binarySHA256"];
    [coder encodeObject:self.source forKey:@"source"];
    [coder encodeObject:self.signatureStatus forKey:@"signatureStatus"];
    [coder encodeObject:self.buildDate forKey:@"buildDate"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _helperID = [coder decodeObjectOfClass:NSString.class forKey:@"helperID"] ?: @"";
        _version = [coder decodeObjectOfClass:NSString.class forKey:@"version"] ?: @"";
        _buildID = [coder decodeObjectOfClass:NSString.class forKey:@"buildID"] ?: @"";
        _protocolVersion = [coder decodeObjectOfClass:NSString.class forKey:@"protocolVersion"] ?: @"";
        _architecture = [coder decodeObjectOfClass:NSString.class forKey:@"architecture"] ?: @"";
        NSNumber *size = [coder decodeObjectOfClass:NSNumber.class forKey:@"binarySize"];
        _binarySize = size ? size.unsignedLongLongValue : 0;
        _binarySHA256 = [coder decodeObjectOfClass:NSString.class forKey:@"binarySHA256"] ?: @"";
        _source = [coder decodeObjectOfClass:NSString.class forKey:@"source"] ?: @"unknown";
        _signatureStatus = [coder decodeObjectOfClass:NSString.class forKey:@"signatureStatus"] ?: @"unknown";
        _buildDate = [coder decodeObjectOfClass:NSDate.class forKey:@"buildDate"];
    }
    return self;
}

@end
