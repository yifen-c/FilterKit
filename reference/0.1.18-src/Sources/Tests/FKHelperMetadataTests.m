#import "FKHelperMetadataTests.h"
#import "FKHelperReleaseMetadata.h"
#import "FKHelperBuildInfo.h"

@implementation FKHelperMetadataTests

+ (NSUInteger)checkCount { return 6; }

+ (NSDictionary *)completeMetadataDictionary {
    return @{
        @"helperID": @"com.filterkit.helper",
        @"version": @"0.1.18",
        @"buildID": @"FKH-0118",
        @"protocolVersion": @"1.0",
        @"architecture": @"arm64e",
        @"binarySize": @(2048),
        @"binarySHA256": @"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
        @"source": @"trusted_repo",
        @"signatureStatus": @"unsupported",
        @"buildDate": @"2026-11-12T10:00:00+08:00"
    };
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // HFM801：元数据字段完整时 isComplete 为 YES。
    FKHelperReleaseMetadata *metadata = [FKHelperReleaseMetadata metadataFromDictionary:[self completeMetadataDictionary]];
    if (!metadata.isComplete) {
        [failures addObject:@"HFM801 完整元数据未被识别为齐备"];
    }

    // HFM802：JSON 序列化保留关键字段。
    NSDictionary *json = metadata.JSONDictionary;
    if (![json[@"helperID"] isEqualToString:@"com.filterkit.helper"] ||
        ![json[@"buildID"] isEqualToString:@"FKH-0118"] ||
        ![json[@"protocolVersion"] isEqualToString:@"1.0"]) {
        [failures addObject:@"HFM802 元数据 JSON 序列化丢失关键字段"];
    }

    // HFM803：JSON 反序列化往返保留字段。
    FKHelperReleaseMetadata *roundTrip = [FKHelperReleaseMetadata metadataFromDictionary:json];
    if (![roundTrip.helperID isEqualToString:metadata.helperID] ||
        ![roundTrip.buildID isEqualToString:metadata.buildID] ||
        roundTrip.binarySize != metadata.binarySize) {
        [failures addObject:@"HFM803 元数据 JSON 往返字段丢失"];
    }

    // HFM804：缺失字段能被识别为不完整。
    FKHelperReleaseMetadata *empty = [FKHelperReleaseMetadata new];
    if ([empty isComplete]) {
        [failures addObject:@"HFM804 空元数据未被识别为缺失字段"];
    }
    NSMutableDictionary *missingDigest = [[self completeMetadataDictionary] mutableCopy];
    missingDigest[@"binarySHA256"] = @"";
    FKHelperReleaseMetadata *noDigest = [FKHelperReleaseMetadata metadataFromDictionary:missingDigest];
    if ([noDigest isComplete]) {
        [failures addObject:@"HFM804 缺少摘要的元数据未被识别为不完整"];
    }

    // HFM805：构建信息可以独立导出并往返。
    FKHelperBuildInfo *buildInfo = [FKHelperBuildInfo buildInfoFromDictionary:@{
        @"productVersion": @"0.1.18",
        @"buildNumber": @"1",
        @"sdkVersion": @"iPhoneOS17.0",
        @"minimumOSVersion": @"15.0",
        @"architectures": @[@"arm64", @"arm64e"],
        @"sourceRevision": @"main"
    }];
    NSDictionary *buildJSON = buildInfo.JSONDictionary;
    NSArray *archs = buildJSON[@"architectures"];
    if (![archs isKindOfClass:NSArray.class] || archs.count != 2) {
        [failures addObject:@"HFM805 构建信息架构集合导出错误"];
    }
    FKHelperBuildInfo *buildRoundTrip = [FKHelperBuildInfo buildInfoFromDictionary:buildJSON];
    if (buildRoundTrip.architectures.count != 2 || ![buildRoundTrip.productVersion isEqualToString:@"0.1.18"]) {
        [failures addObject:@"HFM805 构建信息往返丢失字段"];
    }

    // HFM806：元数据完整不代表身份可信；元数据字典不得自带身份可信结论键。
    if (json[@"identityVerified"] != nil || json[@"trustVerified"] != nil) {
        [failures addObject:@"HFM806 元数据不应携带身份可信结论"];
    }

    return failures.copy;
}

@end
