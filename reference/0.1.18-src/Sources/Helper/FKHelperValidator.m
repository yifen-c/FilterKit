#import "FKHelperValidator.h"

@implementation FKHelperValidator

- (instancetype)init {
    if ((self = [super init])) {
        // 后续接入 Helper 签名校验后，在此依据签名/授权结果置位。
        _identityVerified = NO;
    }
    return self;
}

+ (BOOL)validateRequest:(NSString *)pluginID operationName:(NSString *)operationName error:(NSError **)error {
    if (![pluginID isKindOfClass:NSString.class] || pluginID.length == 0) {
        if (error) *error = [NSError errorWithDomain:FKHelperErrorDomain code:FKHelperErrorInvalidRequest
            userInfo:@{NSLocalizedDescriptionKey: @"插件标识为空"}];
        return NO;
    }
    if (!FKHelperOperationIsAllowed(operationName)) {
        if (error) *error = [NSError errorWithDomain:FKHelperErrorDomain code:FKHelperErrorUnknownOperation
            userInfo:@{NSLocalizedDescriptionKey: @"操作不在白名单内"}];
        return NO;
    }
    return YES;
}

+ (BOOL)validateTargetPath:(NSString *)path withinRoot:(NSString *)root error:(NSError **)error {
    if (![path isKindOfClass:NSString.class] || path.length == 0 ||
        ![root isKindOfClass:NSString.class] || root.length == 0) {
        if (error) *error = [NSError errorWithDomain:FKHelperErrorDomain code:FKHelperErrorInvalidRequest
            userInfo:@{NSLocalizedDescriptionKey: @"路径或可信根为空"}];
        return NO;
    }
    NSString *normalizedPath = [path stringByStandardizingPath];
    NSString *normalizedRoot = [root stringByStandardizingPath];
    if (![normalizedRoot hasSuffix:@"/"]) normalizedRoot = [normalizedRoot stringByAppendingString:@"/"];
    if (![normalizedPath hasPrefix:normalizedRoot]) {
        if (error) *error = [NSError errorWithDomain:FKHelperErrorDomain code:FKHelperErrorPathOutOfBounds
            userInfo:@{NSLocalizedDescriptionKey: @"目标路径越出可信根目录"}];
        return NO;
    }
    return YES;
}

@end
