#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 握手状态。0.1.15 不建立真实连接；握手模型只记录协商结论与对端身份占位。
typedef NS_ENUM(NSInteger, FKHelperHandshakeStatus) {
    FKHelperHandshakeStatusIdle = 0,          /// 未发起
    FKHelperHandshakeStatusRequested,         /// 已发起请求
    FKHelperHandshakeStatusAccepted,          /// 对端接受
    FKHelperHandshakeStatusRejected,           /// 对端拒绝
    FKHelperHandshakeStatusIncompatible,      /// 协议版本不兼容
    FKHelperHandshakeStatusPeerUnverified      /// 对端身份未验证
};

/// v1 握手协商模型。握手通过不等于身份可信；对端身份仍须由独立身份验证确认。
@interface FKHelperHandshake : NSObject

/// 客户端协议主版本。
@property (nonatomic, assign) NSInteger clientProtocolMajor;
/// 客户端协议次版本。
@property (nonatomic, assign) NSInteger clientProtocolMinor;
/// 对端 Helper ID；未验证前为空。
@property (nonatomic, copy, nullable) NSString *peerHelperID;
/// 握手状态。
@property (nonatomic, assign) FKHelperHandshakeStatus status;
/// 握手随机值。
@property (nonatomic, copy) NSString *nonce;
/// 握手时间。
@property (nonatomic, strong) NSDate *timestamp;

/// 与给定协议版本是否兼容（主版本一致即视为兼容，次版本向后兼容）。
- (BOOL)isProtocolCompatibleWithMajor:(NSInteger)major minor:(NSInteger)minor;

- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
