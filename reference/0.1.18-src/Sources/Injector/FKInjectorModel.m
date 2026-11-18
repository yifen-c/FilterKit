#import "FKInjectorModel.h"

@implementation FKInjectorModel

+ (instancetype)modelFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    FKInjectorModel *model = [self new];
    model.raw = dict;
    model.injectorID = dict[@"injector_type"] ?: dict[@"injector_id"] ?: @"unknown";
    model.name = model.injectorID;
    if ([dict[@"version"] isKindOfClass:NSString.class]) model.version = dict[@"version"];
    model.packageID = dict[@"package_id"] ?: @"";
    model.versionSource = dict[@"version_source"] ?: @"none";
    model.detected = [dict[@"detected"] boolValue] || ![model.injectorID isEqualToString:@"unknown"];

    if (!model.detected) {
        model.evidenceLevel = @"unknown";
    } else if (model.version.length && [model.versionSource isEqualToString:@"dpkg_status"]) {
        model.evidenceLevel = @"verified";
    } else {
        model.evidenceLevel = @"partial";
    }
    return model;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"injector_id": self.injectorID ?: @"unknown",
        @"name": self.name ?: @"",
        @"version": self.version ?: @"",
        @"package_id": self.packageID ?: @"",
        @"version_source": self.versionSource ?: @"none",
        @"evidence_level": self.evidenceLevel ?: @"unknown",
        @"detected": @(self.detected)
    };
}

@end
