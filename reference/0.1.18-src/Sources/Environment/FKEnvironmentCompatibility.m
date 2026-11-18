#import "FKEnvironmentCompatibility.h"

NSString *FKCompatibilityCode(FKCompatibilityStatus status) {
    switch (status) {
        case FKCompatibilityStatusPassed: return @"passed";
        case FKCompatibilityStatusPartial: return @"partial";
        case FKCompatibilityStatusFailed: return @"failed";
        case FKCompatibilityStatusUnsupported: return @"unsupported";
        case FKCompatibilityStatusUnknown:
        default: return @"unknown";
    }
}

NSString *FKCompatibilityText(FKCompatibilityStatus status) {
    switch (status) {
        case FKCompatibilityStatusPassed: return @"环境证据充分";
        case FKCompatibilityStatusPartial: return @"部分证据不足";
        case FKCompatibilityStatusFailed: return @"环境不可用";
        case FKCompatibilityStatusUnsupported: return @"当前环境不支持";
        case FKCompatibilityStatusUnknown:
        default: return @"证据不足，无法判定";
    }
}
