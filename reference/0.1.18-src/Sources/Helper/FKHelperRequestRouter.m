#import "FKHelperRequestRouter.h"
#import "FKHelperMessage.h"
#import "FKHelperMessageError.h"
#import "FKHelperReadOnlyProvider.h"

@interface FKHelperRequestRouter ()
@property (nonatomic, strong) FKHelperNonceCache *nonceCache;
@end

@implementation FKHelperRequestRouter

- (instancetype)init {
    self = [super init];
    if (self) _nonceCache = [FKHelperNonceCache new];
    return self;
}

- (void)handleRequest:(FKHelperMessage *)request
           completion:(void (^)(FKHelperMessage *))completion {
    if (!completion) return;

    if (!request || request.messageType != FKHelperMessageRequest) {
        completion([self errorResponseForRequest:request code:FKHelperMessageErrorInvalidMessage]);
        return;
    }

    // 服务端必须独立校验完整报文；不能假设客户端已经执行过本地校验。
    NSError *validationError = nil;
    if (![request validateWithError:&validationError]) {
        FKHelperMessageErrorCode code = (FKHelperMessageErrorCode)validationError.code;
        if (code < FKHelperMessageErrorInvalidMessage || code > FKHelperMessageErrorInvalidNonce) {
            code = FKHelperMessageErrorInvalidMessage;
        }
        completion([self errorResponseForRequest:request code:code]);
        return;
    }

    // 服务端会话内 Nonce 去重：客户端本地校验不能替代服务端防重放。
    if (![self.nonceCache adoptNonce:request.nonce timestamp:[request.timestamp timeIntervalSince1970]]) {
        completion([self errorResponseForRequest:request code:FKHelperMessageErrorReplayDetected]);
        return;
    }

    // 严格白名单：非白名单方法（含全部写方法）拒绝，不进入任何 Provider。
    if (![FKHelperMessage isReadOnlyMethodWhitelisted:request.method]) {
        completion([self errorResponseForRequest:request code:FKHelperMessageErrorUnsupportedMethod]);
        return;
    }

    // 参数校验先于 Provider 分支，Provider 缺失也不能把非法请求伪装成成功。
    if ([request.method isEqualToString:@"plugin.inspect"]) {
        id rawID = request.payload[@"pluginID"] ?: request.payload[@"identifier"];
        if (![rawID isKindOfClass:NSString.class] || [(NSString *)rawID length] == 0 ||
            [(NSString *)rawID length] > 255) {
            completion([self errorResponseForRequest:request code:FKHelperMessageErrorInvalidMessage]);
            return;
        }
    }

    id<FKHelperReadOnlyProvider> provider = self.provider;
    NSDictionary *payload = nil;
    if (!provider) {
        if ([request.method isEqualToString:@"plugin.list"]) {
            payload = @{@"source": @"unsupported", @"plugins": @[]};
        } else if ([request.method isEqualToString:@"plugin.inspect"]) {
            payload = @{@"source": @"unsupported", @"found": @NO};
        } else if ([request.method isEqualToString:@"capabilities.list"]) {
            payload = @{@"source": @"unsupported", @"capabilities": @[]};
        } else if ([request.method isEqualToString:@"config.inspect"]) {
            payload = @{@"source": @"unsupported", @"entries": @[], @"validationStatus": @"unsupported"};
        } else {
            payload = @{@"source": @"unsupported"};
        }
    } else if ([request.method isEqualToString:@"helper.info"]) {
        payload = provider.helperInfo ?: @{@"source": @"unknown"};
    } else if ([request.method isEqualToString:@"helper.health"]) {
        payload = provider.helperHealth ?: @{@"source": @"unknown"};
    } else if ([request.method isEqualToString:@"capabilities.list"]) {
        // Provider 未声明能力来源时只返回空集合，不能推断为完整能力集。
        payload = @{@"source": @"unknown", @"capabilities": @[]};
    } else if ([request.method isEqualToString:@"plugin.list"]) {
        NSArray *plugins = provider.pluginList;
        BOOL valid = [plugins isKindOfClass:NSArray.class];
        for (id item in plugins ?: @[]) {
            if (![item isKindOfClass:NSDictionary.class]) { valid = NO; break; }
        }
        payload = valid ? @{@"source": @"unknown", @"plugins": plugins ?: @[]} :
                          @{@"source": @"invalid", @"plugins": @[]};
    } else if ([request.method isEqualToString:@"plugin.inspect"]) {
        id rawID = request.payload[@"pluginID"] ?: request.payload[@"identifier"];
        if (![rawID isKindOfClass:NSString.class] || [rawID length] == 0) {
            completion([self errorResponseForRequest:request code:FKHelperMessageErrorInvalidMessage]);
            return;
        }
        NSDictionary *info = [provider pluginInfoForIdentifier:(NSString *)rawID];
        payload = info ? @{@"source": @"unknown", @"found": @YES, @"plugin": info} :
                         @{@"source": @"unknown", @"found": @NO};
    } else if ([request.method isEqualToString:@"config.inspect"]) {
        payload = provider.configurationSnapshot ?: @{@"source": @"unknown", @"entries": @[]};
    } else {
        payload = @{@"source": @"unsupported"};
    }

    completion([self successResponseForRequest:request payload:payload]);
}

#pragma mark - Private

- (FKHelperMessage *)errorResponseForRequest:(nullable FKHelperMessage *)request
                                         code:(FKHelperMessageErrorCode)code {
    FKHelperMessage *resp = [FKHelperMessage new];
    resp.messageType = FKHelperMessageResponse;
    resp.requestID = request.requestID ?: @"";
    resp.method = request.method ?: @"";
    resp.protocolMajor = request.protocolMajor;
    resp.protocolMinor = request.protocolMinor;
    resp.responseStatus = @"error";
    resp.errorPayload = @{
        @"code": @(code),
        @"reason": [FKHelperMessageError reasonCodeForCode:code]
    };
    return resp;
}

- (FKHelperMessage *)successResponseForRequest:(FKHelperMessage *)request
                                       payload:(NSDictionary *)payload {
    FKHelperMessage *resp = [FKHelperMessage new];
    resp.messageType = FKHelperMessageResponse;
    resp.requestID = request.requestID;
    resp.method = request.method;
    resp.protocolMajor = request.protocolMajor;
    resp.protocolMinor = request.protocolMinor;
    resp.responseStatus = @"ok";
    resp.payload = payload;
    return resp;
}

@end
