#import <Foundation/Foundation.h>
#import "FKHelperIdentity.h"
#import "FKHelperMetadata.h"
#import "FKHelperCapabilities.h"

NS_ASSUME_NONNULL_BEGIN

/// 未来独立 Helper 的只读服务端信息快照。0.1.15 仅建模数据结构，不生成 Root Daemon，
/// 不代表本机已存在可读写系统文件的后台服务。
@interface FKHelperServiceInfo : NSObject

/// Helper 身份。
@property (nonatomic, strong) FKHelperIdentity *identity;
/// 本地采集到的候选元数据。
@property (nonatomic, strong) FKHelperMetadata *metadata;
/// 已登记能力。
@property (nonatomic, strong) FKHelperCapabilities *capabilities;
/// 服务是否就绪；未通过完整信任链前不得置 YES。
@property (nonatomic, assign) BOOL ready;

- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
