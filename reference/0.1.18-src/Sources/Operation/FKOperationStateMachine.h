#import <Foundation/Foundation.h>
#import "FKOperationModels.h"

NS_ASSUME_NONNULL_BEGIN

/// 事务状态机错误域。
extern NSErrorDomain const FKOperationStateMachineErrorDomain;

typedef NS_ENUM(NSInteger, FKOperationStateMachineErrorCode) {
    FKOperationStateMachineErrorInvalidTransition = 1,  /// 当前状态不允许流转到目标状态
    FKOperationStateMachineErrorTerminal                 /// 已处于终态，不可再流转
};

/// 受控操作事务状态机。只在本地维护合法流转顺序，不执行任何系统变更；
/// 真实 apply 通道在 Gate/Helper 未就绪时保持拒绝。
@interface FKOperationStateMachine : NSObject

/// 当前事务状态。
@property (nonatomic, assign, readonly) FKOperationTransactionState state;

/// 目标状态是否为终态（完成 / 已回滚 / 待人工恢复）。
+ (BOOL)isTerminalState:(FKOperationTransactionState)state;
/// 在不改变内部状态的前提下，判断 from → to 是否为合法流转。
+ (BOOL)canTransitionFrom:(FKOperationTransactionState)from to:(FKOperationTransactionState)to;
/// 状态文案。
+ (NSString *)stateText:(FKOperationTransactionState)state;
/// 状态机器可读标识。
+ (NSString *)stateCode:(FKOperationTransactionState)state;

/// 尝试流转到目标状态；非法流转返回 NO 并写入 error。
- (BOOL)transitionTo:(FKOperationTransactionState)to error:(NSError *_Nullable *_Nullable)error;
/// 复位到初始 Created 状态。
- (void)reset;

@end

NS_ASSUME_NONNULL_END
