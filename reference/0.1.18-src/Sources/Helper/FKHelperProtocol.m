#import "FKHelperProtocol.h"
#import <math.h>

NSErrorDomain const FKHelperErrorDomain = @"com.filterkit.helper";

NSString *const FKHelperOperationNameGetStatus = @"get_status";
NSString *const FKHelperOperationNameValidate = @"validate_operation";
NSString *const FKHelperOperationNameEnable = @"enable_plugin";
NSString *const FKHelperOperationNameDisable = @"disable_plugin";
NSString *const FKHelperOperationNameVerify = @"verify_operation";
NSString *const FKHelperOperationNameRestore = @"restore_operation";

NSString *FKHelperOperationName(FKHelperOperation operation) {
    switch (operation) {
        case FKHelperOperationGetStatus: return FKHelperOperationNameGetStatus;
        case FKHelperOperationValidate: return FKHelperOperationNameValidate;
        case FKHelperOperationEnable: return FKHelperOperationNameEnable;
        case FKHelperOperationDisable: return FKHelperOperationNameDisable;
        case FKHelperOperationVerify: return FKHelperOperationNameVerify;
        case FKHelperOperationRestore: return FKHelperOperationNameRestore;
        default: return nil;
    }
}

BOOL FKHelperOperationIsAllowed(NSString *operationName) {
    if (![operationName isKindOfClass:NSString.class]) return NO;
    NSArray<NSString *> *allowed = @[FKHelperOperationNameGetStatus, FKHelperOperationNameValidate,
                                     FKHelperOperationNameEnable, FKHelperOperationNameDisable,
                                     FKHelperOperationNameVerify, FKHelperOperationNameRestore];
    return [allowed containsObject:operationName];
}

const NSInteger FKHelperProtocolVersion = 1;
const NSTimeInterval FKHelperRequestMaxAge = 300;
NSString *const FKHelperExpectedHelperIdentifier = @"com.filterkit.helper";

static NSError *FKHelperProtocolError(FKHelperErrorCode code, NSString *description) {
    return [NSError errorWithDomain:FKHelperErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

BOOL FKHelperValidateRequest(NSDictionary *request, NSError **error) {
    if (![request isKindOfClass:NSDictionary.class]) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorInvalidRequest, @"请求报文不是结构化字典");
        return NO;
    }
    if ([request[@"protocol_version"] integerValue] != FKHelperProtocolVersion) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorIncompatible, @"协议版本不兼容");
        return NO;
    }
    NSString *requestID = request[@"request_id"];
    if (![requestID isKindOfClass:NSString.class] || requestID.length == 0) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorInvalidRequest, @"缺少请求 ID");
        return NO;
    }
    NSString *operation = request[@"operation"];
    if (!FKHelperOperationIsAllowed(operation)) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorUnknownOperation, @"操作不在白名单内");
        return NO;
    }
    NSString *pluginID = request[@"plugin_id"];
    if (![pluginID isKindOfClass:NSString.class] || pluginID.length == 0) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorInvalidRequest, @"缺少插件 ID");
        return NO;
    }
    NSNumber *timestamp = request[@"timestamp"];
    if (![timestamp isKindOfClass:NSNumber.class]) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorInvalidRequest, @"缺少有效时间戳");
        return NO;
    }
    NSTimeInterval age = fabs([timestamp doubleValue] - [[NSDate date] timeIntervalSince1970]);
    if (age > FKHelperRequestMaxAge) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorUnauthorized, @"请求已过期或疑似重放");
        return NO;
    }
    return YES;
}

BOOL FKHelperValidateResponse(NSDictionary *response, NSError **error) {
    if (![response isKindOfClass:NSDictionary.class]) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorInvalidRequest, @"响应报文不是结构化字典");
        return NO;
    }
    if ([response[@"protocol_version"] integerValue] != FKHelperProtocolVersion) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorIncompatible, @"响应协议版本不兼容");
        return NO;
    }
    NSString *requestID = response[@"request_id"];
    if (![requestID isKindOfClass:NSString.class] || requestID.length == 0) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorInvalidRequest, @"响应缺少请求 ID 回带");
        return NO;
    }
    if (![response[@"status"] isKindOfClass:NSString.class] || [response[@"status"] length] == 0) {
        if (error) *error = FKHelperProtocolError(FKHelperErrorInvalidRequest, @"响应缺少状态字段");
        return NO;
    }
    return YES;
}

