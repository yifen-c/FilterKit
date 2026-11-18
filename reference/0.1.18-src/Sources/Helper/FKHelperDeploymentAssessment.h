#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 部署证据评估。只汇总证据，不创建或启动特权进程。
@interface FKHelperDeploymentAssessment : NSObject

/// 严格校验 Mach Service 名称格式，不代表服务已注册。
+ (BOOL)isValidMachServiceName:(nullable NSString *)serviceName;

/// 按证据字典生成部署可行性报告。缺失、类型错误或未知字段均不会通过。
+ (NSDictionary *)assessmentWithEvidence:(nullable NSDictionary *)evidence;

/// 当前源码基线的保守报告：所有设备侧证据均为未验证。
+ (NSDictionary *)defaultAssessment;

@end

NS_ASSUME_NONNULL_END
