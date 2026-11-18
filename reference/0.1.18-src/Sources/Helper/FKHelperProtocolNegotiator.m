#import "FKHelperProtocolNegotiator.h"
#import <CoreFoundation/CoreFoundation.h>

@interface FKHelperProtocolNegotiationResult ()
@property (nonatomic, assign, readwrite) FKHelperProtocolNegotiationStatus status;
@property (nonatomic, assign, readwrite) NSInteger major;
@property (nonatomic, assign, readwrite) NSInteger minor;
@property (nonatomic, copy, readwrite) NSString *reasonCode;
@end

@implementation FKHelperProtocolNegotiationResult
@end

@implementation FKHelperProtocolNegotiator

- (NSArray<NSDictionary *> *)validatedVersions:(NSArray *)versions {
    if (![versions isKindOfClass:NSArray.class] || versions.count == 0 || versions.count > 32) {
        return nil;
    }

    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (id item in versions) {
        if (![item isKindOfClass:NSDictionary.class]) {
            return nil;
        }

        id majorValue = item[@"major"];
        id minorValue = item[@"minor"];
        BOOL majorIsBoolean = [majorValue isKindOfClass:NSNumber.class] &&
            CFGetTypeID((__bridge CFTypeRef)majorValue) == CFBooleanGetTypeID();
        BOOL minorIsBoolean = [minorValue isKindOfClass:NSNumber.class] &&
            CFGetTypeID((__bridge CFTypeRef)minorValue) == CFBooleanGetTypeID();
        if (![majorValue isKindOfClass:NSNumber.class] || majorIsBoolean ||
            ![minorValue isKindOfClass:NSNumber.class] || minorIsBoolean) {
            return nil;
        }

        NSInteger major = [majorValue integerValue];
        NSInteger minor = [minorValue integerValue];
        BOOL majorIsInteger = [majorValue doubleValue] == (double)major;
        BOOL minorIsInteger = [minorValue doubleValue] == (double)minor;
        if (major < 1 || major > 65535 || minor < 0 || minor > 65535 ||
            !majorIsInteger || !minorIsInteger) {
            return nil;
        }

        NSString *key = [NSString stringWithFormat:@"%ld:%ld", (long)major, (long)minor];
        if ([seen containsObject:key]) {
            return nil;
        }
        [seen addObject:key];
        [result addObject:@{@"major": @(major), @"minor": @(minor)}];
    }
    return result.copy;
}

- (FKHelperProtocolNegotiationResult *)negotiateClientVersions:(NSArray<NSDictionary *> *)clientVersions
                                                  helperVersions:(NSArray<NSDictionary *> *)helperVersions {
    FKHelperProtocolNegotiationResult *result = [FKHelperProtocolNegotiationResult new];
    NSArray<NSDictionary *> *client = [self validatedVersions:clientVersions];
    NSArray<NSDictionary *> *helper = [self validatedVersions:helperVersions];
    if (!client || !helper) {
        result.status = FKHelperProtocolNegotiationStatusInvalid;
        result.reasonCode = @"invalid_version_list";
        return result;
    }

    NSInteger bestMajor = 0;
    NSInteger bestMinor = -1;
    for (NSDictionary *clientVersion in client) {
        for (NSDictionary *helperVersion in helper) {
            NSInteger major = [clientVersion[@"major"] integerValue];
            NSInteger minor = [clientVersion[@"minor"] integerValue];
            BOOL isCommon = major == [helperVersion[@"major"] integerValue] &&
                minor == [helperVersion[@"minor"] integerValue];
            BOOL isHigher = major > bestMajor || (major == bestMajor && minor > bestMinor);
            if (isCommon && isHigher) {
                bestMajor = major;
                bestMinor = minor;
            }
        }
    }

    if (bestMajor == 0) {
        result.status = FKHelperProtocolNegotiationStatusRejected;
        result.reasonCode = @"no_common_protocol";
        return result;
    }

    result.status = FKHelperProtocolNegotiationStatusAccepted;
    result.major = bestMajor;
    result.minor = bestMinor;
    result.reasonCode = @"negotiated";
    return result;
}

@end
