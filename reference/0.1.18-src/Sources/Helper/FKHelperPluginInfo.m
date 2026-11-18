#import "FKHelperPluginInfo.h"

@implementation FKHelperPluginInfo

- (instancetype)init {
    self = [super init];
    if (self) {
        _pluginID = @"";
        _source = @"unknown";
        _inspectionStatus = FKPluginInspectionUnknown;
    }
    return self;
}

- (BOOL)isFromRealReadSource {
    return [self.source isEqualToString:@"injector_api"] || [self.source isEqualToString:@"filesystem_metadata"];
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"pluginID": self.pluginID ?: @"",
        @"displayName": self.displayName ?: @"",
        @"filename": self.filename ?: @"",
        @"source": self.source ?: @"unknown",
        @"architecture": self.architecture ?: @"",
        @"fileSize": @(self.fileSize),
        @"sha256": self.sha256 ?: @"",
        @"bundleID": self.bundleID ?: @"",
        @"injectorID": self.injectorID ?: @"",
        @"inspectionStatus": [FKHelperPluginInfo inspectionStatusCode:self.inspectionStatus],
        @"inspectionStatusText": [FKHelperPluginInfo inspectionStatusText:self.inspectionStatus],
        @"evidenceSource": self.evidenceSource ?: @"",
        @"realReadSource": @(self.isFromRealReadSource)
    };
}

+ (NSString *)inspectionStatusCode:(FKPluginInspectionStatus)status {
    switch (status) {
        case FKPluginInspectionReadable:      return @"readable";
        case FKPluginInspectionIncomplete:    return @"incomplete";
        case FKPluginInspectionInvalid:       return @"invalid";
        case FKPluginInspectionUnsupported:   return @"unsupported";
        case FKPluginInspectionUnknown:
        default:                              return @"unknown";
    }
}

+ (NSString *)inspectionStatusText:(FKPluginInspectionStatus)status {
    switch (status) {
        case FKPluginInspectionReadable:      return @"元数据可读";
        case FKPluginInspectionIncomplete:    return @"元数据不完整";
        case FKPluginInspectionInvalid:       return @"信息无效";
        case FKPluginInspectionUnsupported:   return @"来源不受支持";
        case FKPluginInspectionUnknown:
        default:                              return @"未知";
    }
}

@end
