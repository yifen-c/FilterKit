#import "FKHelperProtocolTests.h"
#import "FKHelperMessage.h"
#import "FKHelperMessageError.h"
#import "FKHelperCapabilities.h"
#import "FKHelperHandshake.h"

@implementation FKHelperProtocolTests

+ (NSUInteger)checkCount { return 16; }

+ (FKHelperMessage *)requestWithMethod:(NSString *)method requestID:(NSString *)requestID {
    FKHelperMessage *message = [FKHelperMessage new];
    message.messageType = FKHelperMessageRequest;
    message.method = method;
    message.requestID = requestID;
    message.nonce = @"nonce-001";
    message.payload = @{};
    return message;
}

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // PRO801：请求 JSON 序列化。
    FKHelperMessage *request = [self requestWithMethod:@"helper.info" requestID:@"req-001"];
    NSError *requestError = nil;
    NSData *requestData = [request JSONData:&requestError];
    if (requestData.length == 0 || requestError != nil) {
        [failures addObject:@"PRO801 请求 JSON 序列化失败"];
    }

    // PRO802：响应 JSON 序列化。
    FKHelperMessage *response = [FKHelperMessage new];
    response.messageType = FKHelperMessageResponse;
    response.requestID = @"req-001";
    response.method = @"helper.info";
    response.payload = @{@"version": @"0.1.18"};
    NSData *responseData = [response JSONData:nil];
    if (responseData.length == 0) {
        [failures addObject:@"PRO802 响应 JSON 序列化失败"];
    }

    // PRO803：请求 JSON 反序列化往返保留关键字段。
    NSError *parseError = nil;
    FKHelperMessage *parsed = [FKHelperMessage messageFromData:requestData error:&parseError];
    if (parsed == nil || ![parsed.requestID isEqualToString:@"req-001"] ||
        ![parsed.method isEqualToString:@"helper.info"]) {
        [failures addObject:@"PRO803 请求 JSON 反序列化字段丢失"];
    }

    // PRO804：无效 JSON 拒绝。
    NSData *invalidData = [@"{not-valid-json" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *invalidError = nil;
    FKHelperMessage *invalid = [FKHelperMessage messageFromData:invalidData error:&invalidError];
    if (invalid != nil || invalidError == nil) {
        [failures addObject:@"PRO804 无效 JSON 应被拒绝并返回错误"];
    }

    // PRO805：协议版本不兼容拒绝。
    FKHelperMessage *badVersion = [self requestWithMethod:@"helper.info" requestID:@"req-002"];
    badVersion.protocolMajor = 2;
    NSError *versionError = nil;
    if ([badVersion validateWithError:&versionError] || versionError.code != FKHelperMessageErrorUnsupportedProtocol) {
        [failures addObject:@"PRO805 不兼容协议版本应被拒绝"];
    }

    // PRO806：Request ID 缺失拒绝。
    FKHelperMessage *noID = [self requestWithMethod:@"helper.info" requestID:@""];
    NSError *idError = nil;
    if ([noID validateWithError:&idError] || idError.code != FKHelperMessageErrorInvalidRequestID) {
        [failures addObject:@"PRO806 缺少 Request ID 应被拒绝"];
    }

    // PRO807：超大消息拒绝。
    NSString *bigPayload = [@"" stringByPaddingToLength:1100 * 1024 withString:@"a" startingAtIndex:0];
    FKHelperMessage *oversize = [self requestWithMethod:@"plugin.list" requestID:@"req-003"];
    oversize.payload = @{@"data": bigPayload};
    NSError *sizeError = nil;
    if ([oversize validateWithError:&sizeError]) {
        [failures addObject:@"PRO807 超大载荷应被拒绝"];
    }

    // PRO808：未知 / 写方法拒绝。
    FKHelperMessage *unknown = [self requestWithMethod:@"plugin.enable" requestID:@"req-004"];
    NSError *methodError = nil;
    if ([unknown validateWithError:&methodError] || methodError.code != FKHelperMessageErrorUnsupportedMethod) {
        [failures addObject:@"PRO808 非白名单方法应被拒绝"];
    }

    // PRO809：Nonce 重复识别。
    FKHelperNonceCache *nonceCache = [FKHelperNonceCache new];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL firstAdopt = [nonceCache adoptNonce:@"nonce-dup" timestamp:now];
    BOOL secondAdopt = [nonceCache adoptNonce:@"nonce-dup" timestamp:now];
    if (!firstAdopt || secondAdopt) {
        [failures addObject:@"PRO809 重复 Nonce 应被识别为重放"];
    }

    // PRO810：超时请求正确处理。
    FKHelperMessage *expired = [self requestWithMethod:@"helper.health" requestID:@"req-005"];
    expired.timestamp = [NSDate dateWithTimeIntervalSinceNow:-600];
    NSError *expireError = nil;
    if ([expired validateWithError:&expireError] || expireError.code != FKHelperMessageErrorExpiredRequest) {
        [failures addObject:@"PRO810 过期请求应被拒绝"];
    }

    // PRO811：错误码完整且均有描述与原因码。
    for (NSInteger code = FKHelperMessageErrorInvalidMessage; code <= FKHelperMessageErrorInvalidNonce; code++) {
        NSString *description = [FKHelperMessageError descriptionForCode:(FKHelperMessageErrorCode)code];
        NSString *reason = [FKHelperMessageError reasonCodeForCode:(FKHelperMessageErrorCode)code];
        if (description.length == 0 || reason.length == 0) {
            [failures addObject:[NSString stringWithFormat:@"PRO811 错误码 %ld 缺少描述或原因码", (long)code]];
        }
    }

    // PRO812：请求与响应按 Request ID 正确匹配。
    FKHelperMessage *matchResp = [FKHelperMessage new];
    matchResp.messageType = FKHelperMessageResponse;
    matchResp.requestID = @"req-001";
    matchResp.method = @"helper.info";
    matchResp.responseStatus = @"ok";
    if (![request matchesResponse:matchResp]) {
        [failures addObject:@"PRO812 同 Request ID 响应应匹配请求"];
    }
    matchResp.requestID = @"req-999";
    if ([request matchesResponse:matchResp]) {
        [failures addObject:@"PRO812 不同 Request ID 响应不应匹配"];
    }

    // PRO813：缺少必需字段的 JSON 必须拒绝，不能静默填默认值。
    NSData *missingFields = [@"{\"protocolMajor\":1,\"requestID\":\"r\"}" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *missingFieldsError = nil;
    if ([FKHelperMessage messageFromData:missingFields error:&missingFieldsError] != nil || missingFieldsError == nil) {
        [failures addObject:@"PRO813 缺少必需字段的报文必须拒绝"];
    }

    // PRO814：非法 messageType 不得被 clamp 成合法枚举。
    NSDictionary *badTypeObject = @{@"protocolMajor": @1, @"protocolMinor": @0, @"requestID": @"r",
                                    @"method": @"helper.info", @"messageType": @9, @"payload": @{},
                                    @"timestamp": @([[NSDate date] timeIntervalSince1970]), @"nonce": @"n",
                                    @"status": @"", @"error": [NSNull null]};
    NSData *badTypeData = [NSJSONSerialization dataWithJSONObject:badTypeObject options:0 error:nil];
    NSError *badTypeError = nil;
    if ([FKHelperMessage messageFromData:badTypeData error:&badTypeError] != nil || badTypeError == nil) {
        [failures addObject:@"PRO814 非法 messageType 必须拒绝"];
    }

    // PRO815：缺少 Nonce 的请求必须拒绝。
    FKHelperMessage *noNonce = [self requestWithMethod:@"helper.info" requestID:@"req-815"];
    noNonce.nonce = @"";
    NSError *nonceError = nil;
    if ([noNonce validateWithError:&nonceError] || nonceError.code != FKHelperMessageErrorInvalidNonce) {
        [failures addObject:@"PRO815 请求缺少 Nonce 必须拒绝"];
    }

    // PRO816：同 Request ID 但方法不同的响应不得匹配。
    FKHelperMessage *wrongMethodResponse = [FKHelperMessage new];
    wrongMethodResponse.messageType = FKHelperMessageResponse;
    wrongMethodResponse.requestID = request.requestID;
    wrongMethodResponse.method = @"plugin.list";
    wrongMethodResponse.responseStatus = @"ok";
    if ([request matchesResponse:wrongMethodResponse]) {
        [failures addObject:@"PRO816 同 Request ID 但方法不同的响应不得匹配"];
    }

    return failures.copy;
}

@end
