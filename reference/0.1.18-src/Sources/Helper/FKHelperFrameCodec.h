#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 四字节网络序长度前缀编解码；不负责 Socket 读写或连接管理。
@interface FKHelperFrameCodec : NSObject
@property (nonatomic, assign) NSUInteger maximumFrameLength;
- (instancetype)initWithMaximumFrameLength:(NSUInteger)maximumFrameLength;
/// 将非空报文编码为 [uint32_be length][payload]。
- (nullable NSData *)frameForPayload:(NSData *)payload error:(NSError **)error;
/// 仅解码完整单帧；长度不符、超限或尾随数据均拒绝。
- (nullable NSData *)payloadFromFrame:(NSData *)frame error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
