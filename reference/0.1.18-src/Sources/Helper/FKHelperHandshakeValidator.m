#import "FKHelperHandshakeValidator.h"
#import "FKHelperIPCHandshake.h"
#import "FKHelperIdentity.h"
#import "FKHelperCapabilities.h"
#import "FKHelperTrust.h"
#import "FKHelperProtocol.h"

static const NSTimeInterval FKHandshakeMaxAge = 300.0;

@implementation FKHelperHandshakeValidator

- (NSArray<NSString *> *)rejectReasonsForRequestID:(NSString *)requestID
                                              nonce:(NSString *)nonce
                                          timestamp:(NSTimeInterval)timestamp
                                           response:(FKHelperIPCHandshakeResponse *)response
                                        trustReport:(FKHelperTrustReport *)trustReport {
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];

    if (!response) {
        [reasons addObject:@"response_missing"];
        return reasons.copy;
    }
    if (requestID.length == 0) [reasons addObject:@"request_id_missing"];
    if (nonce.length == 0) [reasons addObject:@"nonce_missing"];

    // 时间窗：提供时间戳且偏差超出允许范围即拒绝（重放 / 过期报文）。
    if (timestamp > 0 && fabs([[NSDate date] timeIntervalSince1970] - timestamp) > FKHandshakeMaxAge) {
        [reasons addObject:@"timestamp_expired"];
    }

    // 协议版本必须兼容。
    if (response.protocolVersion != FKHelperProtocolVersion) {
        [reasons addObject:@"protocol_incompatible"];
    }

    // 响应身份字段为待验证声明，必须与本地预期身份比对。
    NSString *expectedID = [FKHelperIdentity expectedIdentity].helperID;
    if (response.helperID.length == 0 || ![response.helperID isEqualToString:expectedID]) {
        [reasons addObject:@"helper_id_mismatch"];
    }

    // 清单与对端证据来自本地信任汇总，不以响应自报为准。
    if (![trustReport.manifestStatus isEqualToString:@"verified"]) {
        [reasons addObject:@"manifest_unverified"];
    }
    if (!trustReport.ipcVerified) {
        [reasons addObject:@"peer_unverified"];
    }

    // 响应能力清单不得包含写能力或未知能力。
    NSSet<NSString *> *write = [FKHelperCapabilities writeCapabilityBlacklist];
    for (NSString *cap in response.capabilities ?: @[]) {
        if ([write containsObject:cap] || ![[FKHelperCapabilities readOnlyWhitelist] containsObject:cap]) {
            [reasons addObject:@"unknown_capability"];
            break;
        }
    }

    return reasons.copy;
}

@end
