#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FKHelperCapabilities;

/// 测试专用模拟客户端。所有返回结果必须携带 mock 标记，仅供单元测试与界面占位演示；
/// 生产客户端不得内部回退到此实现，模拟数据不得被记录或报告为设备真实 Helper / 插件状态。
@interface FKMockHelperClient : NSObject

/// 恒为 YES，标识当前为模拟客户端。
@property (nonatomic, readonly) BOOL isMock;

- (void)requestHelperInfo:(void (^)(NSDictionary *_Nullable result, NSError *_Nullable error))completion;
- (void)requestCapabilities:(void (^)(FKHelperCapabilities *_Nullable capabilities, NSError *_Nullable error))completion;
- (void)requestPluginList:(void (^)(NSArray *_Nullable plugins, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
