#import "FKHelperIdentityVerifier.h"
#import "FKHelperProtocol.h"

@implementation FKHelperIdentityVerifier

+ (FKHelperIdentityStatus)verifyIdentityStatusWithPath:(NSString *)path
                                              packageID:(NSString *)packageID
                                                version:(NSString *)version
                                             identifier:(NSString *)identifier
                                                reasons:(NSMutableArray<NSString *> *)reasons {
    BOOL pathExists = path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!pathExists) {
        [reasons addObject:@"Helper 可执行文件不存在或不可访问"];
        return FKHelperIdentityUnknown;
    }

    // 标识与预期不符：明确判 Mismatch，不进入来源评估。
    if (identifier.length > 0 && ![identifier isEqualToString:FKHelperExpectedHelperIdentifier]) {
        [reasons addObject:[NSString stringWithFormat:@"Helper 标识与预期不符：%@", identifier]];
        return FKHelperIdentityMismatch;
    }

    // 必要身份字段缺失：判 Incomplete，待补齐后再评估。
    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    if (packageID.length == 0) [missing addObject:@"软件包标识"];
    if (version.length == 0) [missing addObject:@"版本信息"];
    if (identifier.length == 0) [missing addObject:@"Helper 标识"];
    if (missing.count > 0) {
        [reasons addObject:[NSString stringWithFormat:@"身份信息缺失：%@", [missing componentsJoinedByString:@"、"]]];
        return FKHelperIdentityIncomplete;
    }

    // 字段齐全但缺少可信发布来源 / 官方渠道锚点：保持 Unknown，不臆断为已验证。
    // Verified 仅在接入可信发布记录（签名链 / 可信公钥 / 确认包来源）匹配后才允许进入。
    [reasons addObject:@"缺少可信发布来源与已知版本匹配证据，身份暂不可视为已验证"];
    return FKHelperIdentityUnknown;
}

+ (BOOL)verifyIdentityWithPath:(NSString *)path packageID:(NSString *)packageID version:(NSString *)version reasons:(NSMutableArray<NSString *> *)reasons {
    FKHelperIdentityStatus status = [self verifyIdentityStatusWithPath:path packageID:packageID version:version identifier:nil reasons:reasons];
    return status == FKHelperIdentityVerified;
}

@end
