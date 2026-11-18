#import "FKHelperAuditTests.h"
#import "FKHelperIPCAuditEvent.h"

@implementation FKHelperAuditTests

+ (NSUInteger)checkCount { return 16; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // AUD901：默认来源 unsupported、结果 failed。
    FKHelperIPCAuditEvent *e = [FKHelperIPCAuditEvent new];
    if (![e.source isEqualToString:@"unsupported"] || ![e.result isEqualToString:@"failed"]) {
        [failures addObject:@"AUD901 默认应为 unsupported/failed"];
    }

    // AUD902：connect 动作码。
    if (![[FKHelperIPCAuditEvent actionCode:FKAuditHelperIPCConnect] isEqualToString:@"connect"]) [failures addObject:@"AUD902 connect 动作码不符"];

    // AUD903：plugin_list 动作码。
    if (![[FKHelperIPCAuditEvent actionCode:FKAuditHelperIPCPluginList] isEqualToString:@"plugin_list"]) [failures addObject:@"AUD903 plugin_list 动作码不符"];

    // AUD904：configuration_read 动作码。
    if (![[FKHelperIPCAuditEvent actionCode:FKAuditHelperIPCConfigurationRead] isEqualToString:@"configuration_read"]) [failures addObject:@"AUD904 configuration_read 动作码不符"];

    // AUD905：rejected 动作码。
    if (![[FKHelperIPCAuditEvent actionCode:FKAuditHelperIPCRejected] isEqualToString:@"rejected"]) [failures addObject:@"AUD905 rejected 动作码不符"];

    // AUD906：JSON 含事件标识 / 时间 / 动作 / 结果 / 请求标识。
    e.action = FKAuditHelperIPCPluginList;
    e.requestID = @"req-uuid";
    NSDictionary *json = e.JSONDictionary;
    if (!json[@"eventID"] || !json[@"timestamp"] || !json[@"action"] || !json[@"result"] || ![json[@"requestID"] isEqualToString:@"req-uuid"]) {
        [failures addObject:@"AUD906 审计事件 JSON 字段不完整"];
    }

    // AUD907：成功结果可标记。
    e.result = @"success";
    NSDictionary *jsonResult = e.JSONDictionary;
    if (![jsonResult[@"result"] isEqualToString:@"success"]) [failures addObject:@"AUD907 结果应可标记 success"];

    // AUD908：记录计数序列化。
    e.recordCount = 7;
    NSDictionary *jsonCount = e.JSONDictionary;
    if ([jsonCount[@"recordCount"] unsignedIntegerValue] != 7) [failures addObject:@"AUD908 recordCount 不一致"];

    // AUD909：原因码为空时序列化为 null。
    if (![json[@"reasonCode"] isKindOfClass:NSNull.class]) [failures addObject:@"AUD909 空原因码应为 null"];

    // AUD910：审计记录不承载完整配置 / 文件正文。
    for (NSString *key in @[@"entries", @"configPayload", @"fileContent", @"pluginData"]) {
        if (json[key] != nil && ![json[key] isKindOfClass:NSNull.class]) {
            [failures addObject:[NSString stringWithFormat:@"AUD910 审计记录不得携带正文字段 %@", key]];
        }
    }

    // AUD911：Build ID / Session ID 随事件持久化序列化。
    e.buildID = @"FKH-0118";
    e.sessionID = @"session-001";
    NSDictionary *withSession = e.JSONDictionary;
    if (![withSession[@"buildID"] isEqualToString:@"FKH-0118"] ||
        ![withSession[@"sessionID"] isEqualToString:@"session-001"]) {
        [failures addObject:@"AUD911 审计事件缺少 Build ID / Session ID"];
    }

    // AUD912：持久化字典可以安全重建事件，且不扩展正文数据字段。
    FKHelperIPCAuditEvent *roundTrip = [FKHelperIPCAuditEvent eventFromDictionary:withSession];
    if (roundTrip == nil || ![roundTrip.sessionID isEqualToString:@"session-001"] ||
        ![roundTrip.buildID isEqualToString:@"FKH-0118"]) {
        [failures addObject:@"AUD912 IPC 审计事件持久化往返失败"];
    }

    // AUD913：Peer 绑定审计动作码可往返。
    e.action = FKAuditHelperIPCPeerBinding;
    if (![[FKHelperIPCAuditEvent actionCode:e.action] isEqualToString:@"peer_binding"] ||
        [FKHelperIPCAuditEvent eventFromDictionary:e.JSONDictionary] == nil) {
        [failures addObject:@"AUD913 Peer 绑定审计动作码无效"];
    }
    // AUD914：双向密钥确认动作码可往返。
    e.action = FKAuditHelperIPCKeyConfirmation;
    if (![[FKHelperIPCAuditEvent actionCode:e.action] isEqualToString:@"key_confirmation"] ||
        [FKHelperIPCAuditEvent eventFromDictionary:e.JSONDictionary] == nil) {
        [failures addObject:@"AUD914 密钥确认审计动作码无效"];
    }
    // AUD915：握手状态转换动作码可往返。
    e.action = FKAuditHelperIPCHandshakeState;
    if (![[FKHelperIPCAuditEvent actionCode:e.action] isEqualToString:@"handshake_state"] ||
        [FKHelperIPCAuditEvent eventFromDictionary:e.JSONDictionary] == nil) {
        [failures addObject:@"AUD915 握手状态审计动作码无效"];
    }
    // AUD916：会话过期动作码可往返。
    e.action = FKAuditHelperIPCSessionExpired;
    if (![[FKHelperIPCAuditEvent actionCode:e.action] isEqualToString:@"session_expired"] ||
        [FKHelperIPCAuditEvent eventFromDictionary:e.JSONDictionary] == nil) {
        [failures addObject:@"AUD916 会话过期审计动作码无效"];
    }

    return failures.copy;
}

@end
