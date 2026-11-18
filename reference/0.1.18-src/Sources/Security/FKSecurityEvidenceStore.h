#import <Foundation/Foundation.h>
#import "FKSecurityEvent.h"

/// 安全证据存储：追加式留存安全事件，普通流程只能读取与追加，不能修改或删除历史事件。
@interface FKSecurityEvidenceStore : NSObject

/// 追加一条事件。
- (void)appendEvent:(FKSecurityEvent *)event;
/// 全部事件（按时间先后）。
- (NSArray<FKSecurityEvent *> *)events;
/// 按事件类型码过滤。
- (NSArray<FKSecurityEvent *> *)eventsForType:(NSString *)typeCode;
/// 按事件 ID 查找；找不到返回 nil。
- (FKSecurityEvent *)eventForID:(NSString *)eventID;
/// 清空存储（仅用于测试重置，普通操作流程不调用）。
- (void)reset;

@end
