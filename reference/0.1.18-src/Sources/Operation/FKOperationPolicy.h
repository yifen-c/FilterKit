#import <Foundation/Foundation.h>
#import "FKOperationModels.h"

/// 操作策略：声明当前版本允许的操作模式与必要条件。
/// 0.1.15 固定为只读预演，不开放真实启停；即使检查全部通过也不自动进入 real 模式。
@interface FKOperationPolicy : NSObject

/// 操作模式（preview_only / real）
@property (nonatomic, copy) NSString *mode;
/// 安全模式分级（read_only / preview_only / backup_write / authorized_management）。
@property (nonatomic, assign) FKOperationMode securityMode;
/// 是否允许真实操作；0.1.15 恒为 NO
@property (nonatomic, assign) BOOL allowsRealOperation;
/// 必要条件标识列表
@property (nonatomic, copy) NSArray<NSString *> *requiredRequirementIDs;

/// 当前版本默认策略：只读预演，必要条件覆盖环境、注入器、身份、路径、归属、完整性、Helper、IPC、备份与授权。
+ (instancetype)defaultPolicy;
+ (NSString *)securityModeText:(FKOperationMode)mode;
- (NSDictionary *)JSONDictionary;

@end
