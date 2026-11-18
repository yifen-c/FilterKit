#import "FKInjectorDetector.h"

@implementation FKInjectorDetector

+ (FKInjectorModel *)modelFromDictionary:(NSDictionary *)injectorDictionary {
    FKInjectorModel *model = [FKInjectorModel modelFromDictionary:injectorDictionary];
    if (!model) {
        model = [FKInjectorModel new];
        model.injectorID = @"unknown";
        model.name = @"unknown";
        model.versionSource = @"none";
        model.evidenceLevel = @"unknown";
        model.detected = NO;
    }
    return model;
}

@end
