#import "FKEnvironmentEvidence.h"

static NSString *FKEvidenceConfidenceCode(FKEvidenceConfidence confidence) {
    switch (confidence) {
        case FKEvidenceConfidenceVerified: return @"verified";
        case FKEvidenceConfidencePartial: return @"partial";
        case FKEvidenceConfidenceUnknown:
        default: return @"unknown";
    }
}

static FKEvidenceConfidence FKEvidenceConfidenceFromCode(NSString *code) {
    if ([code isEqualToString:@"verified"]) return FKEvidenceConfidenceVerified;
    if ([code isEqualToString:@"partial"]) return FKEvidenceConfidencePartial;
    return FKEvidenceConfidenceUnknown;
}

@implementation FKEnvironmentEvidence

+ (instancetype)evidenceWithKey:(NSString *)key {
    FKEnvironmentEvidence *evidence = [self new];
    evidence.evidenceKey = key ?: @"";
    return evidence;
}

+ (instancetype)evidenceFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKEnvironmentEvidence *evidence = [self new];
    evidence.evidenceKey = dict[@"key"] ?: @"";
    evidence.path = dict[@"path"] ?: @"";
    evidence.exists = [dict[@"exists"] boolValue];
    evidence.isDirectory = [dict[@"is_directory"] boolValue];
    evidence.readable = [dict[@"readable"] boolValue];
    evidence.source = dict[@"source"] ?: @"";
    evidence.confidence = FKEvidenceConfidenceFromCode(dict[@"confidence"]);
    evidence.detail = dict[@"detail"] ?: @"";
    return evidence;
}

- (NSDictionary *)JSONDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"key"] = self.evidenceKey ?: @"";
    if (self.path.length) json[@"path"] = self.path;
    json[@"exists"] = @(self.exists);
    json[@"is_directory"] = @(self.isDirectory);
    json[@"readable"] = @(self.readable);
    json[@"source"] = self.source ?: @"";
    json[@"confidence"] = FKEvidenceConfidenceCode(self.confidence);
    if (self.detail.length) json[@"detail"] = self.detail;
    return json.copy;
}

@end
