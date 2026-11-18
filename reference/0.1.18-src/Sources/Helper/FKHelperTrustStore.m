#import "FKHelperTrustStore.h"

@implementation FKHelperTrustStore

- (instancetype)init {
    if ((self = [super init])) {
        _policyVersion = @"1.0";
    }
    return self;
}

- (BOOL)hasTrustedAnchorForPackageID:(NSString *)packageID {
    // 0.1.4 尚未接入官方签名链、可信公钥或确认包来源白名单，保守返回 NO。
    NSString *source = [self anchorSourceForPackageID:packageID];
    return source.length > 0 && ![source isEqualToString:@"none"];
}

- (NSString *)anchorSourceForPackageID:(NSString *)packageID {
    // 预留：后续在此维护经确认的包来源映射；当前无可信锚点。
    if (![packageID isKindOfClass:NSString.class] || packageID.length == 0) return @"none";
    return @"none";
}

@end
