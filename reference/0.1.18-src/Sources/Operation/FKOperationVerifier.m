#import "FKOperationVerifier.h"
#import "FKOperationTransaction.h"

static NSString *FKNormalizeState(NSString *state) {
    NSString *text = (state ?: @"").lowercaseString;
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

@implementation FKOperationVerifier

+ (FKVerificationStatus)verifyTargetState:(NSString *)targetState actualState:(nullable NSString *)actualState {
    NSString *target = FKNormalizeState(targetState);
    NSString *actual = FKNormalizeState(actualState);
    if (target.length == 0) return FKVerificationStatusUnknown;
    if (actual.length == 0 || [actual isEqualToString:@"unknown"]) return FKVerificationStatusUnknown;
    return [actual isEqualToString:target] ? FKVerificationStatusPassed : FKVerificationStatusFailed;
}

+ (NSString *)codeForStatus:(FKVerificationStatus)status {
    switch (status) {
        case FKVerificationStatusPassed: return @"passed";
        case FKVerificationStatusFailed: return @"failed";
        case FKVerificationStatusUnknown: return @"unknown";
        case FKVerificationStatusNone:
        default: return @"none";
    }
}

+ (NSString *)textForStatus:(FKVerificationStatus)status {
    switch (status) {
        case FKVerificationStatusPassed: return @"验证通过";
        case FKVerificationStatusFailed: return @"验证未通过";
        case FKVerificationStatusUnknown: return @"无法验证";
        case FKVerificationStatusNone:
        default: return @"未验证";
    }
}

+ (NSDictionary *)verifyTransaction:(FKOperationTransaction *)transaction {
    if (!transaction) {
        return @{@"status": [self codeForStatus:FKVerificationStatusUnknown],
                  @"status_text": [self textForStatus:FKVerificationStatusUnknown],
                  @"reason": @"事务记录缺失"};
    }
    FKVerificationStatus status = [self verifyTargetState:transaction.targetState actualState:transaction.afterState];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"status"] = [self codeForStatus:status];
    result[@"status_text"] = [self textForStatus:status];
    result[@"target_state"] = transaction.targetState ?: @"";
    result[@"actual_state"] = transaction.afterState ?: @"";
    result[@"before_hash"] = transaction.beforeHash ?: @"";
    result[@"after_hash"] = transaction.afterHash ?: @"";
    result[@"matched"] = @(status == FKVerificationStatusPassed);
    switch (status) {
        case FKVerificationStatusUnknown:
            result[@"reason"] = @"未取得可靠的操作后配置证据，配置状态归为未确认";
            break;
        case FKVerificationStatusFailed:
            result[@"reason"] = @"操作后配置与目标状态不一致";
            break;
        case FKVerificationStatusPassed:
            result[@"reason"] = @"操作后配置与目标状态一致";
            break;
        case FKVerificationStatusNone:
        default:
            result[@"reason"] = @"尚未执行验证";
            break;
    }
    return result.copy;
}

@end
