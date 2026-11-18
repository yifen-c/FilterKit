#import "FKHelperConfigurationSnapshot.h"

@implementation FKHelperConfigurationSnapshot

- (instancetype)init {
    self = [super init];
    if (self) {
        _snapshotID = @"";
        _schemaVersion = @"3";
        _entries = @[];
        _capturedAt = [NSDate date];
        _source = @"unsupported";
        _validationStatus = FKConfigurationValidationUnknown;
    }
    return self;
}

- (BOOL)isConfirmedValid {
    return self.validationStatus == FKConfigurationValidationValid &&
           [self.source isEqualToString:@"injector_readonly_provider"];
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"snapshotID": self.snapshotID ?: @"",
        @"injectorID": self.injectorID ?: @"",
        @"schemaVersion": self.schemaVersion ?: @"",
        @"entries": self.entries ?: @[],
        @"recordCount": @(self.entries.count),
        @"capturedAt": @([self.capturedAt timeIntervalSince1970]),
        @"source": self.source ?: @"unsupported",
        @"sha256": self.sha256 ?: @"",
        @"validationStatus": [FKHelperConfigurationSnapshot validationStatusCode:self.validationStatus],
        @"validationStatusText": [FKHelperConfigurationSnapshot validationStatusText:self.validationStatus],
        @"confirmedValid": @(self.isConfirmedValid)
    };
}

+ (NSString *)validationStatusCode:(FKConfigurationValidationStatus)status {
    switch (status) {
        case FKConfigurationValidationValid:       return @"valid";
        case FKConfigurationValidationIncomplete: return @"incomplete";
        case FKConfigurationValidationInvalid:    return @"invalid";
        case FKConfigurationValidationUnsupported: return @"unsupported";
        case FKConfigurationValidationUnavailable:  return @"unavailable";
        case FKConfigurationValidationUnknown:
        default:                                   return @"unknown";
    }
}

+ (NSString *)validationStatusText:(FKConfigurationValidationStatus)status {
    switch (status) {
        case FKConfigurationValidationValid:       return @"配置已确认";
        case FKConfigurationValidationIncomplete: return @"配置不完整";
        case FKConfigurationValidationInvalid:    return @"配置无效";
        case FKConfigurationValidationUnsupported: return @"注入器不提供只读接口";
        case FKConfigurationValidationUnavailable: return @"配置不可读";
        case FKConfigurationValidationUnknown:
        default:                                   return @"未知";
    }
}

@end
