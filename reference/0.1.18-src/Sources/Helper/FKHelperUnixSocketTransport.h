#import <Foundation/Foundation.h>
#import <sys/types.h>
#import "FKHelperTransport.h"

NS_ASSUME_NONNULL_BEGIN

/// Unix-domain socket IPC client. A successful connection requires a socket endpoint,
/// a peer UID match, and a bounded request/response frame. It never grants operation permissions.
@interface FKHelperUnixSocketTransport : NSObject <FKHelperTransport>
@property (nonatomic, copy, readonly) NSString *socketPath;
@property (nonatomic, assign, readonly) uid_t expectedPeerUID;
@property (nonatomic, assign, readonly) uid_t observedPeerUID;
@property (nonatomic, assign, readonly) pid_t observedPeerPID;
@property (nonatomic, assign, readonly) NSTimeInterval timeout;
- (instancetype)initWithSocketPath:(NSString *)socketPath expectedPeerUID:(uid_t)peerUID timeout:(NSTimeInterval)timeout NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// Helper-side listener. Instantiate only inside a separately built Helper process;
/// this class does not launch a daemon or register a launchd/Mach service.
@interface FKHelperUnixSocketServer : NSObject
@property (nonatomic, copy, readonly) NSString *socketPath;
@property (nonatomic, assign, readonly) BOOL running;
- (instancetype)initWithSocketPath:(NSString *)socketPath allowedPeerUID:(uid_t)peerUID handler:(NSData * _Nullable (^)(NSData *request, uid_t peerUID, pid_t peerPID))handler;
- (instancetype)initWithSocketPath:(NSString *)socketPath allowedPeerUID:(uid_t)peerUID socketGroupID:(gid_t)groupID socketMode:(mode_t)mode handler:(NSData * _Nullable (^)(NSData *request, uid_t peerUID, pid_t peerPID))handler NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (BOOL)start:(NSError **)error;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
