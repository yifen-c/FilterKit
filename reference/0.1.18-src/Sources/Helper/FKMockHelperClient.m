#import "FKMockHelperClient.h"
#import "FKHelperCapabilities.h"

@implementation FKMockHelperClient

- (BOOL)isMock {
    return YES;
}

- (void)requestHelperInfo:(void (^)(NSDictionary *_Nullable, NSError *_Nullable))completion {
    NSDictionary *result = @{
        @"mock": @(YES),
        @"helperID": @"com.filterkit.helper",
        @"version": @"0.1.18",
        @"buildID": @"FKH-0118"
    };
    if (completion) completion(result, nil);
}

- (void)requestCapabilities:(void (^)(FKHelperCapabilities *_Nullable, NSError *_Nullable))completion {
    FKHelperCapabilities *capabilities =
        [FKHelperCapabilities capabilitiesWithSet:[FKHelperCapabilities readOnlyWhitelist]];
    if (completion) completion(capabilities, nil);
}

- (void)requestPluginList:(void (^)(NSArray *_Nullable, NSError *_Nullable))completion {
    NSArray *plugins = @[
        @{@"mock": @(YES), @"identifier": @"mock.plugin.placeholder", @"name": @"模拟占位插件"}
    ];
    if (completion) completion(plugins, nil);
}

@end
