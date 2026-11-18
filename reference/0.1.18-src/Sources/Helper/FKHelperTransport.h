#import <Foundation/Foundation.h>
#import "FKHelperTransportState.h"

NS_ASSUME_NONNULL_BEGIN

/// Helper 传输抽象：将协议消息与具体通信方式解耦。
/// 未来可替换为 Unix Socket 适配器或受支持的 IPC 适配器；0.1.15 不连接真实端点，
/// 也不直接依赖 Socket 路径、进程权限或服务注册假设。
@protocol FKHelperTransport <NSObject>

/// 当前传输状态快照。
@property (nonatomic, readonly) FKHelperTransportStatus *status;

/// 是否已连接。仅真实且身份已验证的传输可置 YES；Mock 实现必须返回 NO。
@property (nonatomic, readonly) BOOL connected;

/// 是否为模拟（Mock）实现。
@property (nonatomic, readonly) BOOL isMock;

/// 发起连接；completion 返回成功与否与错误。不阻塞调用线程。
- (void)connectWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion;

/// 发送已序列化的协议数据；completion 返回响应数据或错误。
- (void)sendData:(NSData *)data
      completion:(void (^)(NSData *_Nullable response, NSError *_Nullable error))completion;

/// 断开连接并清理本地状态。
- (void)disconnect;

@end

NS_ASSUME_NONNULL_END
