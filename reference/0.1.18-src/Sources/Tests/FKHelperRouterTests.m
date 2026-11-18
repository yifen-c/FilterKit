#import "FKHelperRouterTests.h"
#import "FKHelperRequestRouter.h"
#import "FKHelperMessage.h"
#import "FKHelperMessageError.h"

@implementation FKHelperRouterTests

+ (NSUInteger)checkCount { return 13; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    FKHelperRequestRouter *router = [FKHelperRequestRouter new]; // 无 Provider，不伪造数据

    FKHelperMessage *(^req)(NSString *) = ^(NSString *method) {
        FKHelperMessage *m = [FKHelperMessage new];
        m.messageType = FKHelperMessageRequest;
        m.requestID = @"req-uuid";
        m.nonce = [NSUUID UUID].UUIDString;
        m.method = method;
        return m;
    };
    FKHelperMessage *(^dispatch)(FKHelperMessage *) = ^(FKHelperMessage *m) {
        __block FKHelperMessage *resp = nil;
        [router handleRequest:m completion:^(FKHelperMessage *r) { resp = r; }];
        return resp;
    };

    // RTE901：未知方法拒绝。
    FKHelperMessage *r901 = dispatch(req(@"foo.bar"));
    if (![r901.responseStatus isEqualToString:@"error"] || r901.errorPayload == nil) [failures addObject:@"RTE901 未知方法应拒绝"];

    // RTE902：写方法 plugin.enable 拒绝。
    FKHelperMessage *r902 = dispatch(req(@"plugin.enable"));
    if (![r902.responseStatus isEqualToString:@"error"]) [failures addObject:@"RTE902 plugin.enable 应拒绝"];

    // RTE903：写方法 config.write 拒绝。
    FKHelperMessage *r903 = dispatch(req(@"config.write"));
    if (![r903.responseStatus isEqualToString:@"error"]) [failures addObject:@"RTE903 config.write 应拒绝"];

    // RTE904：写方法 filter.modify 拒绝。
    FKHelperMessage *r904 = dispatch(req(@"filter.modify"));
    if (![r904.responseStatus isEqualToString:@"error"]) [failures addObject:@"RTE904 filter.modify 应拒绝"];

    // RTE905：helper.info 白名单通过（无 Provider 时数据未提供）。
    FKHelperMessage *r905 = dispatch(req(@"helper.info"));
    if (![r905.responseStatus isEqualToString:@"ok"]) [failures addObject:@"RTE905 helper.info 应放行"];

    // RTE906：plugin.list 白名单通过，无 Provider 时为空列表。
    FKHelperMessage *r906 = dispatch(req(@"plugin.list"));
    NSArray *plugins = r906.payload[@"plugins"];
    if (![r906.responseStatus isEqualToString:@"ok"] || ![plugins isKindOfClass:NSArray.class] || plugins.count != 0) {
        [failures addObject:@"RTE906 plugin.list 应放行且不伪造记录"];
    }

    // RTE907：config.inspect 白名单通过。
    FKHelperMessage *r907 = dispatch(req(@"config.inspect"));
    if (![r907.responseStatus isEqualToString:@"ok"] || ![r907.payload[@"validationStatus"] isEqualToString:@"unsupported"]) [failures addObject:@"RTE907 config.inspect 应返回 Unsupported 快照骨架"];

    // RTE908：请求标识缺失拒绝。
    FKHelperMessage *noID = req(@"helper.info");
    noID.requestID = @"";
    FKHelperMessage *r908 = dispatch(noID);
    if (![r908.responseStatus isEqualToString:@"error"]) [failures addObject:@"RTE908 缺请求标识应拒绝"];

    // RTE909：非请求消息拒绝。
    FKHelperMessage *respType = req(@"helper.info");
    respType.messageType = FKHelperMessageResponse;
    FKHelperMessage *r909 = dispatch(respType);
    if (![r909.responseStatus isEqualToString:@"error"]) [failures addObject:@"RTE909 非请求消息应拒绝"];

    // RTE910：无 Provider 不伪造真实数据，来源标记 unsupported。
    if (![r905.payload[@"source"] isEqualToString:@"unsupported"]) [failures addObject:@"RTE910 无 Provider 应标记 unsupported"];

    // RTE911：capabilities.list 必须返回 capabilities 数组，而不是通用 records。
    FKHelperMessage *r911 = dispatch(req(@"capabilities.list"));
    if (![r911.payload[@"capabilities"] isKindOfClass:NSArray.class] ||
        ![r911.payload[@"source"] isEqualToString:@"unsupported"]) {
        [failures addObject:@"RTE911 capabilities.list 响应结构或来源标记不正确"];
    }

    // RTE912：plugin.inspect 缺少 pluginID 时拒绝，不返回伪成功空对象。
    FKHelperMessage *inspectMissing = req(@"plugin.inspect");
    FKHelperMessage *r912 = dispatch(inspectMissing);
    if (![r912.responseStatus isEqualToString:@"error"]) {
        [failures addObject:@"RTE912 plugin.inspect 缺少标识应拒绝"];
    }

    // RTE913：同一请求重放必须由服务端 Nonce Cache 拒绝。
    FKHelperMessage *replay = req(@"helper.health");
    FKHelperMessage *firstReplay = dispatch(replay);
    FKHelperMessage *secondReplay = dispatch(replay);
    if (![firstReplay.responseStatus isEqualToString:@"ok"] ||
        ![secondReplay.responseStatus isEqualToString:@"error"] ||
        ![secondReplay.errorPayload[@"reason"] isEqualToString:@"replay_detected"]) {
        [failures addObject:@"RTE913 重复 Nonce 请求必须拒绝"];
    }

    return failures.copy;
}

@end
