#import <Foundation/Foundation.h>

/// 准入必要条件定义。每个条件对应 Gate 中的一项检查；任一必要条件不满足即拒绝真实操作。
@interface FKOperationRequirement : NSObject

/// 条件标识（environment / injector / identity / path / ownership / integrity /
/// helper_identity / helper_signature / helper_permission / ipc / policy / backup / authorization）
@property (nonatomic, copy) NSString *requirementID;
/// 展示标题
@property (nonatomic, copy) NSString *title;
/// 是否为必要条件；必要条件不满足即阻断
@property (nonatomic, assign) BOOL required;
/// 条件说明
@property (nonatomic, copy) NSString *summary;

+ (instancetype)requirementWithID:(NSString *)identifier
                              title:(NSString *)title
                            required:(BOOL)required
                             summary:(NSString *)summary;
- (NSDictionary *)JSONDictionary;

@end
