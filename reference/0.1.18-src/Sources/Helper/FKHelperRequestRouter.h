#import <Foundation/Foundation.h>

@class FKHelperMessage;
@protocol FKHelperReadOnlyProvider;

NS_ASSUME_NONNULL_BEGIN

/// 服务端请求路由：只把显式登记的只读方法分发到已定义 Provider。
/// 不接受客户端传入的任意方法名，不动态调用任意 Objective-C selector；
/// 未知方法、写方法、结构非法请求一律拒绝。真实服务端还须校验会话、来源、消息大小与数据范围。
@interface FKHelperRequestRouter : NSObject

/// 只读数据提供者；为空时白名单方法仅返回未提供数据的响应，不伪造真实内容。
@property (nonatomic, weak, nullable) id<FKHelperReadOnlyProvider> provider;

/// 处理一条请求；响应通过 completion 回传。
- (void)handleRequest:(FKHelperMessage *)request
           completion:(void (^)(FKHelperMessage *response))completion;

@end

NS_ASSUME_NONNULL_END
