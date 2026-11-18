#import <Foundation/Foundation.h>
#import "FKHelperDiscovery.h"
#import "FKHelperIdentityVerifier.h"
#import "FKHelperIntegrityVerifier.h"
#import "FKHelperIPCHandshake.h"

@class FKHelperEvidence;

/// Helper 信任逐级状态。只有必要验证全部通过，才允许进入 OPERATION_READY；任一关键证据缺失即停在对应级别或拒绝。
typedef NS_ENUM(NSInteger, FKHelperTrustState) {
    FKHelperTrustStateNotFound = 0,            /// 未发现 Helper
    FKHelperTrustStateDiscovered,             /// 已发现候选，但身份/签名等证据不足
    FKHelperTrustStateIdentityVerified,       /// 身份验证通过
    FKHelperTrustStateSignatureVerified,     /// 签名验证通过
    FKHelperTrustStatePermissionVerified,     /// 权限模型验证通过
    FKHelperTrustStateIPCVerified,            /// IPC 协议验证通过
    FKHelperTrustStateOperationReady,         /// 满足指定操作准入条件
    FKHelperTrustStateRejected                /// 验证失败被拒绝
};

/// 签名证据状态。设备上已安装文件不代表可信；无可验证签名链时不得判通过。
/// Valid/Invalid/AdHoc/Unsigned/Unsupported 为细分状态；Verified/Unverified 为兼容旧口径的别名。
typedef NS_ENUM(NSInteger, FKSignatureStatus) {
    FKSignatureStatusUnknown = 0,
    FKSignatureStatusValid,
    FKSignatureStatusInvalid,
    FKSignatureStatusAdHoc,
    FKSignatureStatusUnsigned,
    FKSignatureStatusUnsupported,
    FKSignatureStatusVerified,    // 兼容别名：等同于 Valid
    FKSignatureStatusUnverified   // 兼容别名：等同于 Unknown
};

/// Helper 信任评估报告：绑定具体候选路径与归属包；验证结果不作为所有插件通用授权。
@interface FKHelperTrustReport : NSObject

/// 候选可执行路径
@property (nonatomic, copy) NSString *path;
/// 归属软件包标识（可追溯证据，可能为空）
@property (nonatomic, copy) NSString *packageID;
/// 识别到的版本（可能为空）
@property (nonatomic, copy) NSString *version;
/// 当前信任级别
@property (nonatomic, assign) FKHelperTrustState state;
/// 签名证据状态
@property (nonatomic, assign) FKSignatureStatus signatureStatus;
/// 身份是否通过
@property (nonatomic, assign) BOOL identityVerified;
/// 签名是否通过
@property (nonatomic, assign) BOOL signatureVerified;
/// 权限模型是否通过
@property (nonatomic, assign) BOOL permissionVerified;
/// IPC 协议是否通过
@property (nonatomic, assign) BOOL ipcVerified;
/// 发现分层状态（仅候选与元数据结论，不产生可信判定）
@property (nonatomic, assign) FKHelperDiscoveryStatus discoveryStatus;
/// 身份细化状态
@property (nonatomic, assign) FKHelperIdentityStatus identityStatus;
/// 完整性细化状态
@property (nonatomic, assign) FKHelperIntegrityStatus integrityStatus;
/// IPC 连接状态
@property (nonatomic, assign) FKHelperIPCStatus ipcStatus;
/// 本地只读能力是否评估可用
@property (nonatomic, assign) BOOL permissionReadOnly;
/// 写操作能力是否开放（阶段一恒为 NO）
@property (nonatomic, assign) BOOL permissionWrite;
/// 是否允许真实操作；阶段一恒为 NO
@property (nonatomic, assign) BOOL realOperationAllowed;
/// 机器可读拒绝/存疑原因码
@property (nonatomic, copy) NSArray<NSString *> *reasonCodes;
/// 未通过/存疑原因列表
@property (nonatomic, copy) NSArray<NSString *> *reasons;
/// 本次检查时间
@property (nonatomic, copy) NSDate *checkedAt;
/// 身份 / 签名 / 权限详细证据；无候选时为空
@property (nonatomic, strong) FKHelperEvidence *evidence;

/// Helper 稳定标识（0.1.15 规划口径 com.filterkit.helper；未发现真实 Helper 时为空）
@property (nonatomic, copy) NSString *helperID;
/// 构建标识（FKH-0115）
@property (nonatomic, copy) NSString *buildID;
/// 发布清单状态机器码（unavailable / unknown / invalid / verified）；0.1.15 无内置可信锚点，默认 unavailable
@property (nonatomic, copy) NSString *manifestStatus;
/// 能力评估映射：本地检查与各只读/写能力的可用或禁止结论
@property (nonatomic, copy) NSDictionary<NSString *, NSNumber *> *capabilities;

/// 状态文案。
+ (NSString *)stateTextForState:(FKHelperTrustState)state;
/// 状态机器可读标识。
+ (NSString *)stateCodeForState:(FKHelperTrustState)state;
/// 身份状态展示文案。
+ (NSString *)identityTextForStatus:(FKHelperIdentityStatus)status;
/// 完整性状态展示文案。
+ (NSString *)integrityTextForStatus:(FKHelperIntegrityStatus)status;
- (NSDictionary *)JSONDictionary;

@end
