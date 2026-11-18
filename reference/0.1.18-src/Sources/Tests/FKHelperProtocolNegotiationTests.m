#import "FKHelperProtocolNegotiationTests.h"
#import "FKHelperProtocolNegotiator.h"

@implementation FKHelperProtocolNegotiationTests

+ (NSUInteger)checkCount {
    return 8;
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperProtocolNegotiator *negotiator = [FKHelperProtocolNegotiator new];
    NSArray *clientVersions = @[
        @{@"major": @1, @"minor": @0},
        @{@"major": @1, @"minor": @2},
        @{@"major": @2, @"minor": @0}
    ];
    NSArray *helperVersions = @[
        @{@"major": @1, @"minor": @1},
        @{@"major": @1, @"minor": @2},
        @{@"major": @2, @"minor": @1}
    ];

    FKHelperProtocolNegotiationResult *result =
        [negotiator negotiateClientVersions:clientVersions helperVersions:helperVersions];
    if (result.status != FKHelperProtocolNegotiationStatusAccepted ||
        result.major != 1 || result.minor != 2) {
        [failures addObject:@"NEG1401 应选择双方共同支持的最高协议版本"];
    }

    result = [negotiator negotiateClientVersions:@[@{@"major": @1, @"minor": @0}]
                                   helperVersions:@[@{@"major": @2, @"minor": @0}]];
    if (result.status != FKHelperProtocolNegotiationStatusRejected) {
        [failures addObject:@"NEG1402 主版本不一致必须拒绝"];
    }

    result = [negotiator negotiateClientVersions:@[] helperVersions:helperVersions];
    if (result.status != FKHelperProtocolNegotiationStatusInvalid) {
        [failures addObject:@"NEG1403 空版本列表必须判为无效"];
    }

    result = [negotiator negotiateClientVersions:@[@{@"major": @YES, @"minor": @0}]
                                   helperVersions:helperVersions];
    if (result.status != FKHelperProtocolNegotiationStatusInvalid) {
        [failures addObject:@"NEG1404 布尔值不得冒充版本号"];
    }

    result = [negotiator negotiateClientVersions:@[@{@"major": @1.5, @"minor": @0}]
                                   helperVersions:helperVersions];
    if (result.status != FKHelperProtocolNegotiationStatusInvalid) {
        [failures addObject:@"NEG1405 小数版本号必须拒绝"];
    }

    result = [negotiator negotiateClientVersions:@[
        @{@"major": @1, @"minor": @0}, @{@"major": @1, @"minor": @0}
    ] helperVersions:helperVersions];
    if (result.status != FKHelperProtocolNegotiationStatusInvalid) {
        [failures addObject:@"NEG1406 重复版本条目必须拒绝"];
    }

    result = [negotiator negotiateClientVersions:@[@{@"major": @1, @"minor": @0}]
                                   helperVersions:@[@{@"major": @1, @"minor": @0}]];
    if (result.minor != 0) {
        [failures addObject:@"NEG1407 次版本 0 应可正确协商"];
    }

    result = [negotiator negotiateClientVersions:@[@{@"major": @65536, @"minor": @0}]
                                   helperVersions:helperVersions];
    if (result.status != FKHelperProtocolNegotiationStatusInvalid) {
        [failures addObject:@"NEG1408 超范围版本号必须拒绝"];
    }

    return failures.copy;
}

@end
