#import "FKHelperSessionLifecycleTests.h"
#import "FKHelperSessionLifecycle.h"
#import "FKHelperKeyLifecycle.h"
@implementation FKHelperSessionLifecycleTests
+ (NSUInteger)checkCount { return 13; }
+ (NSArray<NSString *> *)runChecks {
 NSMutableArray *f=[NSMutableArray array]; FKHelperSessionLifecycle *s=[[FKHelperSessionLifecycle alloc] initWithMaximumLifetime:600 idleTimeout:60];
 NSDate *t=[NSDate dateWithTimeIntervalSince1970:100000];
 if([s isActiveAtDate:t] || [s touchAtDate:t]) [f addObject:@"SLM1800 未建立会话不得报告活跃"];
 if([s beginSessionWithID:@"s" peerBindingVerified:NO clientConfirmationVerified:YES helperConfirmationVerified:YES date:t]) [f addObject:@"SLM1801 未验证 Peer 不得建立会话"];
 if([s beginSessionWithID:@"s" peerBindingVerified:YES clientConfirmationVerified:NO helperConfirmationVerified:YES date:t]) [f addObject:@"SLM1802 未确认客户端密钥不得建立会话"];
 if([s beginSessionWithID:@"s" peerBindingVerified:YES clientConfirmationVerified:YES helperConfirmationVerified:NO date:t]) [f addObject:@"SLM1803 未确认 Helper 密钥不得建立会话"];
 if(![s beginSessionWithID:@"s" peerBindingVerified:YES clientConfirmationVerified:YES helperConfirmationVerified:YES date:t]) [f addObject:@"SLM1804 完整证据应建立会话"];
 if(![s isActiveAtDate:[t dateByAddingTimeInterval:30]]) [f addObject:@"SLM1805 活跃窗口内会话应有效"];
 if([s beginSessionWithID:@"s2" peerBindingVerified:YES clientConfirmationVerified:YES helperConfirmationVerified:YES date:t]) [f addObject:@"SLM1806 活跃会话不得被覆盖"];
 if(![s touchAtDate:[t dateByAddingTimeInterval:40]]) [f addObject:@"SLM1807 空闲超时前触达应成功"];
 if(![s isActiveAtDate:[t dateByAddingTimeInterval:80]]) [f addObject:@"SLM1808 触达后会话应保持有效"];
 if([s isActiveAtDate:[t dateByAddingTimeInterval:700]] || s.state!=FKHelperManagedSessionStateExpired) [f addObject:@"SLM1809 最大寿命到期必须失效"];
 FKHelperSessionLifecycle *manualSession=[[FKHelperSessionLifecycle alloc] initWithMaximumLifetime:600 idleTimeout:60];
 [manualSession beginSessionWithID:@"manual" peerBindingVerified:YES clientConfirmationVerified:YES helperConfirmationVerified:YES date:t];
 [manualSession invalidateWithReason:@"manual" ]; if(manualSession.state!=FKHelperManagedSessionStateInvalidated || [manualSession isActiveAtDate:t]) [f addObject:@"SLM1810 主动失效后不得保持活跃"];
 FKHelperSessionLifecycle *clockSession=[[FKHelperSessionLifecycle alloc] initWithMaximumLifetime:600 idleTimeout:60];
 [clockSession beginSessionWithID:@"clock" peerBindingVerified:YES clientConfirmationVerified:YES helperConfirmationVerified:YES date:t];
 if([clockSession isActiveAtDate:[t dateByAddingTimeInterval:-1]] || clockSession.state!=FKHelperManagedSessionStateInvalidated || ![clockSession.terminalReason isEqualToString:@"clock_rollback"]) [f addObject:@"SLM1811 系统时钟倒退必须使会话失效"];
 FKHelperKeyLifecycle *keyLifecycle=[FKHelperKeyLifecycle new];
 [keyLifecycle createSessionKeyAtDate:t];
 FKHelperSessionLifecycle *keyBoundSession=[[FKHelperSessionLifecycle alloc] initWithMaximumLifetime:600 idleTimeout:60 keyLifecycle:keyLifecycle];
 [keyBoundSession beginSessionWithID:@"key-bound" peerBindingVerified:YES clientConfirmationVerified:YES helperConfirmationVerified:YES date:t];
 [keyBoundSession invalidateWithReason:@"transport_disconnected"];
 if(keyLifecycle.state!=FKHelperKeyStateRevoked) [f addObject:@"SLM1812 会话失效必须撤销会话密钥"];
 return f.copy;
}
@end
