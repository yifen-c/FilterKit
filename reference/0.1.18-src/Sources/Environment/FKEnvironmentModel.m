#import "FKEnvironmentModel.h"

@implementation FKEnvironmentModel

- (NSDictionary *)JSONDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"jailbreak_type"] = self.jailbreakTypeCode ?: @"unknown";
    if (self.jailbreakDisplayName.length) json[@"jailbreak_display_name"] = self.jailbreakDisplayName;

    FKEnvironmentEvidence *jbroot = self.evidence[@"jbroot"];
    NSMutableDictionary *jbrootJSON = [NSMutableDictionary dictionary];
    jbrootJSON[@"path"] = self.jbrootPath ?: @"";
    jbrootJSON[@"detected"] = @(self.jbrootDetected);
    if (jbroot) {
        jbrootJSON[@"exists"] = @(jbroot.exists);
        jbrootJSON[@"is_directory"] = @(jbroot.isDirectory);
        jbrootJSON[@"readable"] = @(jbroot.readable);
        jbrootJSON[@"evidence"] = jbroot.source ?: @"";
    } else {
        jbrootJSON[@"exists"] = @(self.jbrootDetected);
    }
    json[@"jbroot"] = jbrootJSON.copy;

    FKEnvironmentEvidence *injector = self.evidence[@"injector"];
    NSMutableDictionary *injectorJSON = [NSMutableDictionary dictionary];
    injectorJSON[@"name"] = self.injectorName ?: @"";
    injectorJSON[@"version"] = self.injectorVersion ?: @"";
    if (injector) {
        injectorJSON[@"source"] = injector.source ?: @"";
        injectorJSON[@"confidence"] = injector.confidence == FKEvidenceConfidenceVerified ? @"verified"
            : (injector.confidence == FKEvidenceConfidencePartial ? @"partial" : @"unknown");
    }
    json[@"injector"] = injectorJSON.copy;

    json[@"compatibility"] = @{
        @"status": FKCompatibilityCode(self.compatibility),
        @"state_text": FKCompatibilityText(self.compatibility),
        @"reasons": self.compatibilityReasons ?: @[]
    };

    NSMutableArray *evidenceList = [NSMutableArray array];
    for (FKEnvironmentEvidence *item in self.evidence.allValues) [evidenceList addObject:item.JSONDictionary];
    json[@"evidence"] = evidenceList.copy;
    return json.copy;
}

@end
