#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 传输连接状态。0.1.15 不建立真实端点连接，状态只反映本地抽象模型。
typedef NS_ENUM(NSInteger, FKHelperTransportState) {
    FKHelperTransportStateIdle = 0,       /// 未发起
    FKHelperTransportStateConnecting,     /// 连接中
    FKHelperTransportStateConnected,      /// 已连接（仅真实传输可达；Mock 不得置为此态对外报告）
    FKHelperTransportStateDisconnected,   /// 已断开
    FKHelperTransportStateFailed,         /// 连接失败
    FKHelperTransportStateTimeout         /// 通信超时
};

/// 传输错误域。
extern NSErrorDomain const FKHelperTransportErrorDomain;

/// 传输错误码。
typedef NS_ENUM(NSInteger, FKHelperTransportErrorCode) {
    FKHelperTransportErrorUnavailable = 1,  /// 无可用且已验证的 Helper 端点
    FKHelperTransportErrorMock,             /// 当前为测试模拟传输，不是真实连接
    FKHelperTransportErrorTimeout,          /// 超时
    FKHelperTransportErrorIncompatible,     /// 协议不兼容
    FKHelperTransportErrorUnknown
};

/// 传输状态快照：状态、错误、时间戳与是否为模拟实现。
@interface FKHelperTransportStatus : NSObject

/// 连接状态。
@property (nonatomic, assign) FKHelperTransportState state;
/// 关联错误；无错误为空。
@property (nonatomic, strong, nullable) NSError *error;
/// 状态记录时间。
@property (nonatomic, strong) NSDate *timestamp;
/// 是否为模拟（Mock）传输；Mock 必须置 YES，不得被报告为真实连接。
@property (nonatomic, assign) BOOL isMock;

- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
