#import "FKHelperConfigurationTests.h"
#import "FKHelperConfigurationSnapshot.h"

@implementation FKHelperConfigurationTests

+ (NSUInteger)checkCount { return 10; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // CFG901：默认 Unknown / unsupported。
    FKHelperConfigurationSnapshot *s = [FKHelperConfigurationSnapshot new];
    if (s.validationStatus != FKConfigurationValidationUnknown || ![s.source isEqualToString:@"unsupported"]) {
        [failures addObject:@"CFG901 默认应为 Unknown/unsupported"];
    }

    // CFG902：只读接口确认的有效配置。
    FKHelperConfigurationSnapshot *s2 = [FKHelperConfigurationSnapshot new];
    s2.validationStatus = FKConfigurationValidationValid;
    s2.source = @"injector_readonly_provider";
    if (!s2.isConfirmedValid) [failures addObject:@"CFG902 只读接口有效配置应确认"];

    // CFG903：有效但来自自身数据库，不得确认为 Injector 实际配置。
    FKHelperConfigurationSnapshot *s3 = [FKHelperConfigurationSnapshot new];
    s3.validationStatus = FKConfigurationValidationValid;
    s3.source = @"filterkit_database";
    if (s3.isConfirmedValid) [failures addObject:@"CFG903 自身记录不得确认有效"];

    // CFG904：Incomplete 状态。
    FKHelperConfigurationSnapshot *s4 = [FKHelperConfigurationSnapshot new];
    s4.validationStatus = FKConfigurationValidationIncomplete;
    if (![[FKHelperConfigurationSnapshot validationStatusCode:s4.validationStatus] isEqualToString:@"incomplete"]) {
        [failures addObject:@"CFG904 状态码应为 incomplete"];
    }

    // CFG905：Invalid 状态。
    FKHelperConfigurationSnapshot *s5 = [FKHelperConfigurationSnapshot new];
    s5.validationStatus = FKConfigurationValidationInvalid;
    if (![[FKHelperConfigurationSnapshot validationStatusCode:s5.validationStatus] isEqualToString:@"invalid"]) {
        [failures addObject:@"CFG905 状态码应为 invalid"];
    }

    // CFG906：Unsupported 状态。
    FKHelperConfigurationSnapshot *s6 = [FKHelperConfigurationSnapshot new];
    s6.validationStatus = FKConfigurationValidationUnsupported;
    if (![[FKHelperConfigurationSnapshot validationStatusCode:s6.validationStatus] isEqualToString:@"unsupported"]) {
        [failures addObject:@"CFG906 状态码应为 unsupported"];
    }

    // CFG907：Unavailable 状态。
    FKHelperConfigurationSnapshot *s7 = [FKHelperConfigurationSnapshot new];
    s7.validationStatus = FKConfigurationValidationUnavailable;
    if (![[FKHelperConfigurationSnapshot validationStatusCode:s7.validationStatus] isEqualToString:@"unavailable"]) {
        [failures addObject:@"CFG907 状态码应为 unavailable"];
    }

    // CFG908：JSON recordCount 与 entries 一致。
    FKHelperConfigurationSnapshot *s8 = [FKHelperConfigurationSnapshot new];
    s8.entries = @[@{@"bundleID": @"com.example.app", @"pluginIDs": @[@"example.plugin"], @"source": @"injector"}];
    NSDictionary *json = s8.JSONDictionary;
    if ([json[@"recordCount"] unsignedIntegerValue] != s8.entries.count) [failures addObject:@"CFG908 recordCount 不一致"];

    // CFG909：无摘要时为空串，不臆造 SHA256。
    if (s8.sha256.length != 0 || ![json[@"sha256"] isEqualToString:@""]) [failures addObject:@"CFG909 无摘要应为空串"];

    // CFG910：只读快照模型不含写 / 恢复方法。
    NSArray<NSString *> *writeSelectors = @[@"writeToFile:error:", @"restoreEntry:error:", @"applyConfiguration:error:"];
    for (NSString *sel in writeSelectors) {
        if ([FKHelperConfigurationSnapshot instancesRespondToSelector:NSSelectorFromString(sel)]) {
            [failures addObject:[NSString stringWithFormat:@"CFG910 不应含写方法 %@", sel]];
        }
    }

    return failures.copy;
}

@end
