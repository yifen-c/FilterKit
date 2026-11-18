#import <Foundation/Foundation.h>
#import "FKHelperTransport.h"

NS_ASSUME_NONNULL_BEGIN

/// 测试专用模拟传输。仅用于单元测试与接口占位；
/// 必须始终标注 isMock = YES、connected = NO，不得被报告为真实 Helper 连接。
/// 生产客户端不得内部回退到此实现。
@interface FKHelperTestTransport : NSObject <FKHelperTransport>

/// 置为 YES 时，连接与发送回调返回超时错误并进入 Timeout 状态。
@property (nonatomic, assign) BOOL simulateTimeout;

@end

NS_ASSUME_NONNULL_END
