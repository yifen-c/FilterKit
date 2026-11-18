#import "FKEnvironmentDetector.h"
#import "FKEnvironmentValidator.h"

@implementation FKEnvironmentDetector

+ (FKEnvironmentModel *)modelFromEnvironment:(NSDictionary *)environment
                                 filesystem:(NSDictionary *)filesystem {
    NSDictionary *env = [environment isKindOfClass:NSDictionary.class] ? environment : @{};
    (void)filesystem; // 保留 filesystem 补充证据入口；本期以 environment 字典与只读探测为准。
    FKEnvironmentModel *model = [FKEnvironmentModel new];
    model.rawEnvironment = env;

    // 越狱类型：优先使用结论码，缺失时由展示名保守派生。
    NSString *typeCode = env[@"jailbreak_type"] ?: @"";
    NSString *displayName = env[@"jailbreak"] ?: @"";
    if (typeCode.length == 0) {
        if ([displayName hasPrefix:@"RootHide"]) typeCode = @"roothide";
        else if ([displayName containsString:@"Rootless"]) typeCode = @"rootless";
        else typeCode = @"unknown";
    }
    model.jailbreakTypeCode = typeCode;
    model.jailbreakDisplayName = displayName;

    // JBROOT 路径与只读探测证据。
    id jbrootValue = env[@"jbroot"];
    NSString *jbrootPath = [jbrootValue isKindOfClass:NSString.class] ? jbrootValue : @"";
    model.jbrootPath = jbrootPath;
    model.jbrootDetected = [env[@"jbroot_detected"] boolValue] || jbrootPath.length > 0;

    FKEnvironmentEvidence *jbrootEvidence = [FKEnvironmentEvidence evidenceWithKey:@"jbroot"];
    jbrootEvidence.path = jbrootPath;
    jbrootEvidence.source = @"filesystem_probe";
    if (jbrootPath.length > 0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDir = NO;
        BOOL exists = [fm fileExistsAtPath:jbrootPath isDirectory:&isDir];
        jbrootEvidence.exists = exists;
        jbrootEvidence.isDirectory = isDir;
        jbrootEvidence.readable = exists && [fm isReadableFileAtPath:jbrootPath];
        jbrootEvidence.confidence = exists ? FKEvidenceConfidenceVerified : FKEvidenceConfidenceUnknown;
    } else {
        jbrootEvidence.exists = NO;
        jbrootEvidence.confidence = FKEvidenceConfidenceUnknown;
        jbrootEvidence.detail = @"未定位到 JBROOT 路径";
    }

    // 注入器证据：识别类型、版本与版本来源；裸 dylib 存在不推断版本或启停能力。
    NSDictionary *injector = [env[@"injector"] isKindOfClass:NSDictionary.class] ? env[@"injector"] : @{};
    NSString *injectorName = injector[@"injector_type"] ?: @"";
    NSString *injectorVersion = [injector[@"version"] isKindOfClass:NSString.class] ? injector[@"version"] : @"";
    NSString *versionSource = injector[@"version_source"] ?: @"";
    BOOL injectorIdentified = [injector[@"detected"] boolValue] || ![injectorName isEqualToString:@"unknown"];
    model.injectorName = injectorIdentified ? injectorName : @"";
    model.injectorVersion = injectorVersion;

    FKEnvironmentEvidence *injectorEvidence = [FKEnvironmentEvidence evidenceWithKey:@"injector"];
    injectorEvidence.source = versionSource.length ? versionSource : @"derived";
    if (!injectorIdentified) {
        injectorEvidence.confidence = FKEvidenceConfidenceUnknown;
        injectorEvidence.detail = @"未取得足够证据识别注入器";
    } else if (injectorVersion.length && [versionSource isEqualToString:@"dpkg_status"]) {
        injectorEvidence.confidence = FKEvidenceConfidenceVerified;
    } else {
        injectorEvidence.confidence = FKEvidenceConfidencePartial;
    }

    model.evidence = @{@"jbroot": jbrootEvidence, @"injector": injectorEvidence};

    // 兼容性由证据重新派生；路径不可读只归 Partial/Unknown，不直接判环境不兼容。
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];
    model.compatibility = [FKEnvironmentValidator evaluateWithTypeCode:typeCode
                                                        jbrootDetected:model.jbrootDetected
                                                         jbrootReadable:jbrootEvidence.readable
                                                    injectorIdentified:injectorIdentified
                                                             supported:YES
                                                               reasons:reasons];
    model.compatibilityReasons = reasons.copy;
    return model;
}

@end
