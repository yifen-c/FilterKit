#import <Foundation/Foundation.h>
#import "FKOperationModels.h"
#import "FKOperationStateMachine.h"
#import "FKOperationGate.h"

NS_ASSUME_NONNULL_BEGIN

/// 单次受控操作事务：聚合请求、状态机、门禁检查、前后状态/哈希、备份、验证与回滚结论。
/// 事务只在本地记录流转与结论；真实变更须经可信 Helper 通道，0.1.15 通道未就绪时保持拒绝。
@interface FKOperationTransaction : NSObject

/// 事务唯一标识（与请求 ID 一致）。
@property (nonatomic, copy) NSString *operationID;
/// 原始操作请求。
@property (nonatomic, strong) FKOperationRequest *request;
/// 事务状态机。
@property (nonatomic, strong) FKOperationStateMachine *stateMachine;
/// 本次准入决策。
@property (nonatomic, assign) FKOperationDecision decision;
/// 门禁检查项快照。
@property (nonatomic, copy) NSArray<FKOperationCheck *> *checks;
/// 阻止 / 存疑原因列表。
@property (nonatomic, copy) NSArray<NSString *> *reasons;

/// 操作前配置状态文本。
@property (nonatomic, copy, nullable) NSString *beforeState;
/// 目标配置状态文本。
@property (nonatomic, copy, nullable) NSString *targetState;
/// 操作后实际配置状态文本。
@property (nonatomic, copy, nullable) NSString *afterState;
/// 操作前哈希。
@property (nonatomic, copy, nullable) NSString *beforeHash;
/// 操作后哈希。
@property (nonatomic, copy, nullable) NSString *afterHash;
/// 操作前备份 ID。
@property (nonatomic, copy, nullable) NSString *backupID;
/// 验证结论码。
@property (nonatomic, copy, nullable) NSString *verificationResult;
/// 回滚结论码。
@property (nonatomic, copy, nullable) NSString *rollbackResult;
/// 失败 / 拒绝原因。
@property (nonatomic, copy, nullable) NSString *failureReason;
/// Helper 身份 / 版本 / 协议版本（未验证时为空）。
@property (nonatomic, copy, nullable) NSString *helperIdentity;
@property (nonatomic, copy, nullable) NSString *helperVersion;
@property (nonatomic, copy, nullable) NSString *protocolVersion;

@property (nonatomic, copy) NSDate *createdAt;
@property (nonatomic, copy) NSDate *updatedAt;

+ (instancetype)transactionWithRequest:(FKOperationRequest *)request;
/// 推进状态机到目标状态；非法流转返回 NO。
- (BOOL)advanceTo:(FKOperationTransactionState)state error:(NSError *_Nullable *_Nullable)error;
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
