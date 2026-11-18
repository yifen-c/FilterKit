#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 能力清单：区分本地只读、IPC 只读与写操作权限。
/// 阶段一本地只读可评估，IPC 只读与写能力默认关闭；能力不等于已通过身份或签名验证。
@interface FKHelperIPCCapabilities : NSObject

/// 只读权限键集合（本地只读 + IPC 只读）
@property (nonatomic, copy) NSArray<NSString *> *readOnlyPermissions;
/// 写操作权限键集合
@property (nonatomic, copy) NSArray<NSString *> *writePermissions;

+ (instancetype)capabilitiesWithReadOnly:(NSArray<NSString *> *)readOnlyPermissions
                                   write:(NSArray<NSString *> *)writePermissions;
- (BOOL)containsPermission:(NSString *)permission;
- (BOOL)isWritePermission:(NSString *)permission;
- (NSDictionary *)JSONDictionary;

@end

NS_ASSUME_NONNULL_END
