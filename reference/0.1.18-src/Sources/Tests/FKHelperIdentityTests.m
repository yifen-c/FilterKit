#import "FKHelperIdentityTests.h"
#import "FKHelperIdentity.h"

@implementation FKHelperIdentityTests

+ (NSUInteger)checkCount { return 8; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperIdentity *expected = [FKHelperIdentity expectedIdentity];

    // HFA801：Helper ID 固定且唯一。
    if (![expected.helperID isEqualToString:@"com.filterkit.helper"]) {
        [failures addObject:@"HFA801 Helper ID 不是 com.filterkit.helper"];
    }

    // HFA802：Product ID 正确。
    if (![expected.productID isEqualToString:@"FilterKit"]) {
        [failures addObject:@"HFA802 Product ID 错误"];
    }

    // HFA803：Component ID 正确。
    if (![expected.componentID isEqualToString:@"FilterKitHelper"]) {
        [failures addObject:@"HFA803 Component ID 错误"];
    }

    // HFA804：Version 格式有效（非空且含语义版本分隔符）。
    if (expected.version.length == 0 || ![expected.version containsString:@"."]) {
        [failures addObject:@"HFA804 Version 格式无效"];
    }

    // HFA805：Build ID 非空。
    if (expected.buildID.length == 0) {
        [failures addObject:@"HFA805 Build ID 为空"];
    }

    // HFA806：协议版本可解析（major 1 / minor 0）。
    if (expected.protocolMajor != 1 || expected.protocolMinor != 0) {
        [failures addObject:@"HFA806 协议版本不是 1.0"];
    }

    // HFA807：空身份字段应被结构校验拒绝。
    FKHelperIdentity *empty = [FKHelperIdentity new];
    if ([empty isStructurallyValid]) {
        [failures addObject:@"HFA807 空身份字段未被拒绝"];
    }
    FKHelperIdentity *partial = [FKHelperIdentity new];
    partial.helperID = @"com.filterkit.helper";
    if ([partial isStructurallyValid]) {
        [failures addObject:@"HFA807 缺失其余字段的身份未被拒绝"];
    }

    // HFA808：身份逐项比较。
    FKHelperIdentity *copy = [FKHelperIdentity expectedIdentity];
    if (![expected matchesIdentity:copy]) {
        [failures addObject:@"HFA808 相同身份比较应相等"];
    }
    copy.buildID = @"FKH-999";
    if ([expected matchesIdentity:copy]) {
        [failures addObject:@"HFA808 Build ID 不同的身份不应相等"];
    }
    if ([expected matchesIdentity:nil]) {
        [failures addObject:@"HFA808 与 nil 身份比较应返回 NO"];
    }

    return failures.copy;
}

@end
