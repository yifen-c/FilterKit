#import <Foundation/Foundation.h>

@class FKHelperTrustReport, FKPluginState, FKOperationRequest, FKOperationResult;

NS_ASSUME_NONNULL_BEGIN

/// Helper 连接错误域。
extern NSErrorDomain const FKHelperConnectionErrorDomain;

typedef NS_ENUM(NSInteger, FKHelperConnectionErrorCode) {
    FKHelperConnectionErrorUnavailable = 1,   /// 无可用且身份已验证的 Helper 端点
    FKHelperConnectionErrorUnverified,         /// 身份 / 签名 / 权限尚未验证通过
    FKHelperConnectionErrorIncompatible,      /// 协议版本或注入器类型不兼容
    FKHelperConnectionErrorUnknownTarget      /// 目标 App 或插件身份不明确
};

/// Helper 连接抽象：定义 App 与受控 Helper 之间的应用层接口边界。
/// 0.1.15 未取得可信端点与受支持协议证据，available 恒为 NO，不建立任何真实 IPC 连接；
/// 方法内一律安全拒绝，不向未验证服务发送请求，不修改系统配置。
@interface FKHelperConnection : NSObject

/// 是否存在已通过身份、签名、权限与协议验证的 Helper 通道；当前版本恒为 NO。
@property (nonatomic, assign, readonly) BOOL available;

/// 校验连接与信任身份；仅汇总本地已有信任报告，不连接端点。
- (void)verifyConnectionWithCompletion:(void (^)(FKHelperTrustReport *_Nullable report))completion;

/// 查询插件在目标 App 下的配置 / 运行状态；无通道时返回 Unknown 状态与错误。
- (void)queryPluginState:(NSString *)pluginID
            appBundleID:(nullable NSString *)appBundleID
             completion:(void (^)(FKPluginState *_Nullable state, NSError *_Nullable error))completion;

/// 提交已通过 Gate 与用户授权的白名单操作；通道未就绪时安全拒绝。
- (void)applyAuthorizedOperation:(FKOperationRequest *)request
                       completion:(void (^)(FKOperationResult *_Nullable result, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
