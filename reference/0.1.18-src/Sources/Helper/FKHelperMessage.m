#import "FKHelperMessage.h"
#import "FKHelperMessageError.h"
#import <float.h>

const NSUInteger FKHelperMessageMaxPayloadBytes = 1024 * 1024;
const NSTimeInterval FKHelperMessageMaxAge = 300;

@interface FKHelperNonceCache ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *records;
@end

@implementation FKHelperNonceCache

- (instancetype)init {
    self = [super init];
    if (self) {
        _records = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)adoptNonce:(NSString *)nonce timestamp:(NSTimeInterval)timestamp {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (nonce.length == 0 || fabs(now - timestamp) > FKHelperMessageMaxAge) return NO;
    @synchronized (self.records) {
        // 清理过期条目，避免长生命周期 Helper 的重放缓存无限增长。
        NSArray<NSString *> *keys = self.records.allKeys;
        for (NSString *key in keys) {
            NSTimeInterval stored = self.records[key].doubleValue;
            if (fabs(now - stored) > FKHelperMessageMaxAge) [self.records removeObjectForKey:key];
        }
        if (self.records[nonce] != nil) return NO;
        // 缓存满时拒绝新请求，不淘汰仍处于有效期的 Nonce。
        if (self.records.count >= 4096) return NO;
        self.records[nonce] = @(timestamp);
        return YES;
    }
}

- (void)reset {
    @synchronized (self.records) {
        [self.records removeAllObjects];
    }
}

@end

@interface FKHelperMessage ()
+ (NSSet<NSString *> *)readOnlyWhitelist;
@end

@implementation FKHelperMessage

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (NSSet<NSString *> *)readOnlyWhitelist {
    static NSSet<NSString *> *whitelist;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        whitelist = [NSSet setWithArray:@[
            @"helper.info",
            @"helper.health",
            @"capabilities.list",
            @"plugin.list",
            @"plugin.inspect",
            @"config.inspect"
        ]];
    });
    return whitelist;
}

+ (BOOL)isReadOnlyMethodWhitelisted:(NSString *)method {
    if (method.length == 0) {
        return NO;
    }
    return [[self readOnlyWhitelist] containsObject:method];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _protocolMajor = 1;
        _protocolMinor = 0;
        _payload = @{};
        _timestamp = [NSDate date];
        _responseStatus = @"";
    }
    return self;
}

- (NSDictionary *)payloadDictionary {
    return self.payload ?: @{};
}

- (NSData *)JSONData:(NSError **)error {
    if (![self.payload isKindOfClass:NSDictionary.class] ||
        self.requestID.length == 0 ||
        self.method.length == 0 ||
        self.protocolMajor < 1 || self.protocolMinor < 0 ||
        self.messageType < FKHelperMessageRequest || self.messageType > FKHelperMessageEvent ||
        (self.messageType == FKHelperMessageRequest && ![[self class] isReadOnlyMethodWhitelisted:self.method])) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:FKHelperMessageErrorDomain
                                         code:FKHelperMessageErrorInvalidMessage
                                     userInfo:@{NSLocalizedDescriptionKey: @"报文包含缺失或不受支持的字段"}];
        }
        return nil;
    }

    NSDictionary *json = @{
        @"protocolMajor": @(self.protocolMajor),
        @"protocolMinor": @(self.protocolMinor),
        @"requestID": self.requestID,
        @"method": self.method,
        @"messageType": @(self.messageType),
        @"payload": self.payload,
        @"timestamp": @(self.timestamp ? [self.timestamp timeIntervalSince1970] : 0),
        @"nonce": self.nonce ?: @"",
        @"status": self.responseStatus ?: @"",
        @"error": self.errorPayload ?: [NSNull null]
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:error];
    if (data.length > FKHelperMessageMaxPayloadBytes) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:FKHelperMessageErrorDomain
                                         code:FKHelperMessageErrorInvalidMessage
                                     userInfo:@{NSLocalizedDescriptionKey: @"完整报文超过消息大小上限"}];
        }
        return nil;
    }
    return data;
}

+ (nullable instancetype)messageFromData:(NSData *)data error:(NSError **)error {
    if (data.length == 0 || data.length > FKHelperMessageMaxPayloadBytes) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:FKHelperMessageErrorDomain
                                         code:FKHelperMessageErrorInvalidMessage
                                     userInfo:@{NSLocalizedDescriptionKey: data.length == 0 ? @"报文数据为空" : @"完整报文超过消息大小上限"}];
        }
        return nil;
    }

    NSError *parseError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (![parsed isKindOfClass:NSDictionary.class]) {
        if (error != NULL) *error = parseError ?: [NSError errorWithDomain:FKHelperMessageErrorDomain
                                                                       code:FKHelperMessageErrorInvalidMessage
                                                                   userInfo:@{NSLocalizedDescriptionKey: @"报文根节点必须为对象"}];
        return nil;
    }

    NSDictionary *dict = (NSDictionary *)parsed;
    id major = dict[@"protocolMajor"];
    id minor = dict[@"protocolMinor"];
    id requestID = dict[@"requestID"];
    id method = dict[@"method"];
    id messageType = dict[@"messageType"];
    id payload = dict[@"payload"];
    id timestamp = dict[@"timestamp"];
    id nonce = dict[@"nonce"];
    id status = dict[@"status"];
    id errorPayload = dict[@"error"];

    BOOL fieldsValid = [major isKindOfClass:NSNumber.class] &&
        [minor isKindOfClass:NSNumber.class] &&
        [requestID isKindOfClass:NSString.class] &&
        [method isKindOfClass:NSString.class] &&
        [messageType isKindOfClass:NSNumber.class] &&
        [payload isKindOfClass:NSDictionary.class] &&
        [timestamp isKindOfClass:NSNumber.class] &&
        [nonce isKindOfClass:NSString.class] &&
        [status isKindOfClass:NSString.class] &&
        (errorPayload != nil && (errorPayload == NSNull.null || [errorPayload isKindOfClass:NSDictionary.class]));

    if (!fieldsValid) {
        if (error != NULL) *error = [NSError errorWithDomain:FKHelperMessageErrorDomain
                                                         code:FKHelperMessageErrorInvalidMessage
                                                     userInfo:@{NSLocalizedDescriptionKey: @"报文缺少必需字段或字段类型错误"}];
        return nil;
    }

    NSInteger typeValue = [((NSNumber *)messageType) integerValue];
    if (typeValue < FKHelperMessageRequest || typeValue > FKHelperMessageEvent ||
        [((NSNumber *)major) doubleValue] != [((NSNumber *)major) integerValue] ||
        [((NSNumber *)minor) doubleValue] != [((NSNumber *)minor) integerValue] ||
        [((NSNumber *)messageType) doubleValue] != typeValue) {
        if (error != NULL) *error = [NSError errorWithDomain:FKHelperMessageErrorDomain
                                                         code:FKHelperMessageErrorInvalidMessage
                                                     userInfo:@{NSLocalizedDescriptionKey: @"协议版本或消息类型数值非法"}];
        return nil;
    }

    FKHelperMessage *message = [FKHelperMessage new];
    message.protocolMajor = [((NSNumber *)major) integerValue];
    message.protocolMinor = [((NSNumber *)minor) integerValue];
    message.requestID = (NSString *)requestID;
    message.method = (NSString *)method;
    message.messageType = (FKHelperMessageType)typeValue;
    message.payload = (NSDictionary *)payload;
    message.timestamp = [NSDate dateWithTimeIntervalSince1970:[((NSNumber *)timestamp) doubleValue]];
    message.nonce = (NSString *)nonce;
    message.responseStatus = (NSString *)status;
    message.errorPayload = ([errorPayload isKindOfClass:NSDictionary.class] ? (NSDictionary *)errorPayload : nil);

    NSError *validationError = nil;
    if (![message validateWithError:&validationError]) {
        if (error != NULL) *error = validationError;
        return nil;
    }
    return message;
}

- (BOOL)validateWithError:(NSError **)error {
    FKHelperMessageErrorCode code = FKHelperMessageErrorUnknown;
    NSString *failure = nil;

    if (self.protocolMajor != 1 || self.protocolMinor < 0) {
        code = FKHelperMessageErrorUnsupportedProtocol;
        failure = @"协议版本不受支持";
    } else if (self.requestID.length == 0) {
        code = FKHelperMessageErrorInvalidRequestID;
        failure = @"请求标识缺失";
    } else if (self.messageType < FKHelperMessageRequest || self.messageType > FKHelperMessageEvent ||
               self.method.length == 0 || ![self.payload isKindOfClass:NSDictionary.class]) {
        code = FKHelperMessageErrorInvalidMessage;
        failure = @"消息结构或字段非法";
    } else if (self.messageType == FKHelperMessageRequest && ![FKHelperMessage isReadOnlyMethodWhitelisted:self.method]) {
        code = FKHelperMessageErrorUnsupportedMethod;
        failure = @"方法不在 v1 只读白名单内";
    } else if (self.messageType == FKHelperMessageRequest && self.nonce.length == 0) {
        code = FKHelperMessageErrorInvalidNonce;
        failure = @"请求缺少防重放随机值";
    } else if (self.messageType == FKHelperMessageResponse &&
               ![@[@"ok", @"error"] containsObject:(self.responseStatus ?: @"")]) {
        code = FKHelperMessageErrorInvalidMessage;
        failure = @"响应状态必须为 ok 或 error";
    } else if (self.messageType == FKHelperMessageResponse &&
               [self.responseStatus isEqualToString:@"error"] && self.errorPayload == nil) {
        code = FKHelperMessageErrorInvalidMessage;
        failure = @"错误响应缺少错误对象";
    } else {
        NSData *payloadData = [NSJSONSerialization dataWithJSONObject:self.payload options:0 error:nil];
        if (payloadData == nil || payloadData.length > FKHelperMessageMaxPayloadBytes) {
            code = FKHelperMessageErrorInvalidMessage;
            failure = @"载荷超过消息大小上限或无法序列化";
        } else if (self.timestamp) {
            NSTimeInterval age = fabs([[NSDate date] timeIntervalSinceDate:self.timestamp]);
            if (age > FKHelperMessageMaxAge) {
                code = FKHelperMessageErrorExpiredRequest;
                failure = @"请求时间戳超出有效窗口";
            }
        }
    }

    if (failure != nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:FKHelperMessageErrorDomain
                                         code:code
                                     userInfo:@{NSLocalizedDescriptionKey: failure,
                                                @"reasonCode": [FKHelperMessageError reasonCodeForCode:code]}];
        }
        return NO;
    }
    return YES;
}

- (BOOL)matchesResponse:(FKHelperMessage *)response {
    if (response == nil || self.messageType != FKHelperMessageRequest) return NO;
    if (response.messageType != FKHelperMessageResponse ||
        ![response.requestID isEqualToString:self.requestID] ||
        ![response.method isEqualToString:self.method] ||
        response.protocolMajor != self.protocolMajor ||
        response.protocolMinor != self.protocolMinor) return NO;
    NSError *error = nil;
    return [response validateWithError:&error];
}

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.protocolMajor forKey:@"protocolMajor"];
    [coder encodeInteger:self.protocolMinor forKey:@"protocolMinor"];
    [coder encodeObject:self.requestID forKey:@"requestID"];
    [coder encodeObject:self.method forKey:@"method"];
    [coder encodeInteger:self.messageType forKey:@"messageType"];
    [coder encodeObject:self.payload forKey:@"payload"];
    [coder encodeObject:self.timestamp forKey:@"timestamp"];
    [coder encodeObject:self.nonce forKey:@"nonce"];
    [coder encodeObject:self.responseStatus forKey:@"responseStatus"];
    [coder encodeObject:self.errorPayload forKey:@"errorPayload"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _protocolMajor = [coder decodeIntegerForKey:@"protocolMajor"];
        _protocolMinor = [coder decodeIntegerForKey:@"protocolMinor"];
        _requestID = [coder decodeObjectOfClass:NSString.class forKey:@"requestID"] ?: @"";
        _method = [coder decodeObjectOfClass:NSString.class forKey:@"method"] ?: @"";
        _messageType = (FKHelperMessageType)[coder decodeIntegerForKey:@"messageType"];
        _payload = [coder decodeObjectOfClass:NSDictionary.class forKey:@"payload"] ?: @{};
        _timestamp = [coder decodeObjectOfClass:NSDate.class forKey:@"timestamp"] ?: [NSDate date];
        _nonce = [coder decodeObjectOfClass:NSString.class forKey:@"nonce"] ?: @"";
        _responseStatus = [coder decodeObjectOfClass:NSString.class forKey:@"responseStatus"] ?: @"";
        _errorPayload = [coder decodeObjectOfClass:NSDictionary.class forKey:@"errorPayload"];
    }
    return self;
}

@end
