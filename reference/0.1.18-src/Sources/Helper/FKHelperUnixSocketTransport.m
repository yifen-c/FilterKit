#import "FKHelperUnixSocketTransport.h"
#import "FKHelperFrameCodec.h"
#import <sys/socket.h>
#import <arpa/inet.h>
#import <math.h>
#import <sys/un.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
#import <limits.h>

static NSError *FKUnixError(NSInteger code, NSString *message, int systemError) {
    NSMutableDictionary *info = [@{NSLocalizedDescriptionKey: message ?: @"Unix Socket error"} mutableCopy];
    if (systemError) info[NSUnderlyingErrorKey] = [NSError errorWithDomain:NSPOSIXErrorDomain code:systemError userInfo:nil];
    return [NSError errorWithDomain:FKHelperTransportErrorDomain code:code userInfo:info];
}
static BOOL FKUnixPathValid(NSString *path) {
    if (![path isKindOfClass:NSString.class] || !path.isAbsolutePath || path.length == 0) return NO;
    const char *p = path.fileSystemRepresentation;
    return p && strlen(p) < sizeof(((struct sockaddr_un *)0)->sun_path) && ![path containsString:@"/../"] && ![path hasSuffix:@"/.."];
}
static BOOL FKWriteAll(int fd, const void *bytes, size_t length) {
    const uint8_t *p = bytes; size_t offset = 0;
    while (offset < length) { ssize_t n = send(fd, p + offset, length - offset, 0); if (n < 0 && errno == EINTR) continue; if (n <= 0) return NO; offset += (size_t)n; }
    return YES;
}
static BOOL FKReadAll(int fd, void *bytes, size_t length) {
    uint8_t *p = bytes; size_t offset = 0;
    while (offset < length) { ssize_t n = recv(fd, p + offset, length - offset, 0); if (n < 0 && errno == EINTR) continue; if (n <= 0) return NO; offset += (size_t)n; }
    return YES;
}
static BOOL FKSendFrame(int fd, NSData *payload) {
    FKHelperFrameCodec *codec = [[FKHelperFrameCodec alloc] initWithMaximumFrameLength:1024 * 1024];
    NSData *frame = [codec frameForPayload:payload error:nil];
    return frame && FKWriteAll(fd, frame.bytes, frame.length);
}
static NSData *FKReceiveFrame(int fd) {
    uint32_t header = 0; if (!FKReadAll(fd, &header, sizeof(header))) return nil;
    uint32_t length = ntohl(header); if (length == 0 || length > 1024 * 1024) return nil;
    NSMutableData *payload = [NSMutableData dataWithLength:length];
    return FKReadAll(fd, payload.mutableBytes, length) ? payload.copy : nil;
}
static void FKSetSocketTimeout(int fd, NSTimeInterval timeout) {
    struct timeval tv; tv.tv_sec = (time_t)MAX(1, floor(timeout)); tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)); setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
#ifdef SO_NOSIGPIPE
    int yes = 1; setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
#endif
}

@interface FKHelperUnixSocketTransport ()
@property (nonatomic, copy, readwrite) NSString *socketPath;
@property (nonatomic, assign, readwrite) uid_t expectedPeerUID;
@property (nonatomic, assign, readwrite) uid_t observedPeerUID;
@property (nonatomic, assign, readwrite) pid_t observedPeerPID;
@property (nonatomic, assign, readwrite) NSTimeInterval timeout;
@property (nonatomic, strong, readwrite) FKHelperTransportStatus *status;
@property (nonatomic, assign) int socketFD;
@property (nonatomic, strong) dispatch_queue_t queue;
@end
@implementation FKHelperUnixSocketTransport
- (instancetype)initWithSocketPath:(NSString *)socketPath expectedPeerUID:(uid_t)peerUID timeout:(NSTimeInterval)timeout {
    self = [super init]; if (self) { _socketPath = [socketPath copy] ?: @""; _expectedPeerUID = peerUID; _timeout = MIN(MAX(timeout, 1.0), 15.0); _socketFD = -1; _observedPeerUID = (uid_t)-1; _observedPeerPID = -1; _status = [FKHelperTransportStatus new]; _status.isMock = NO; _queue = dispatch_queue_create("com.filterkit.helper.unix-transport", DISPATCH_QUEUE_SERIAL); } return self;
}
- (BOOL)isMock { return NO; }
- (BOOL)connected { @synchronized (self) { return self.socketFD >= 0 && self.status.state == FKHelperTransportStateConnected; } }
- (BOOL)openSocket:(NSError **)error {
    if (!FKUnixPathValid(self.socketPath)) { if (error) *error = FKUnixError(FKHelperTransportErrorUnavailable, @"Socket 路径无效或超长", 0); return NO; }
    struct stat st; if (lstat(self.socketPath.fileSystemRepresentation, &st) != 0 || !S_ISSOCK(st.st_mode)) { if (error) *error = FKUnixError(FKHelperTransportErrorUnavailable, @"Endpoint 不存在或不是 Unix Socket", errno); return NO; }
    int fd = socket(AF_UNIX, SOCK_STREAM, 0); if (fd < 0) { if (error) *error = FKUnixError(FKHelperTransportErrorUnknown, @"创建 Socket 失败", errno); return NO; }
    FKSetSocketTimeout(fd, self.timeout);
    struct sockaddr_un address; memset(&address, 0, sizeof(address)); address.sun_family = AF_UNIX; strlcpy(address.sun_path, self.socketPath.fileSystemRepresentation, sizeof(address.sun_path));
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) { int e = errno; close(fd); if (error) *error = FKUnixError(FKHelperTransportErrorUnavailable, @"连接 Helper Socket 失败", e); return NO; }
    uid_t uid = (uid_t)-1; gid_t gid = (gid_t)-1;
    if (getpeereid(fd, &uid, &gid) != 0 || uid != self.expectedPeerUID) { int e = errno; close(fd); if (error) *error = FKUnixError(FKHelperTransportErrorIncompatible, @"Peer UID 验证失败", e); return NO; }
    @synchronized (self) { self.socketFD = fd; self.observedPeerUID = uid; self.status.state = FKHelperTransportStateConnected; self.status.timestamp = [NSDate date]; self.status.error = nil; }
    return YES;
}
- (void)connectWithCompletion:(void (^)(BOOL, NSError *))completion {
    dispatch_async(self.queue, ^{ NSError *error = nil; if (!self.connected) { self.status.state = FKHelperTransportStateConnecting; self.status.timestamp = [NSDate date]; } BOOL ok = self.connected || [self openSocket:&error]; if (!ok) { self.status.state = FKHelperTransportStateFailed; self.status.error = error; self.status.timestamp = [NSDate date]; } if (completion) completion(ok, error); });
}
- (void)sendData:(NSData *)data completion:(void (^)(NSData *, NSError *))completion {
    dispatch_async(self.queue, ^{ NSError *error = nil; NSData *response = nil;
        if (![data isKindOfClass:NSData.class] || data.length == 0 || data.length > 1024 * 1024) error = FKUnixError(FKHelperTransportErrorIncompatible, @"请求为空或超过 1 MiB", 0);
        if (!error && !self.connected && ![self openSocket:&error]) { }
        int fd = -1; @synchronized (self) { fd = self.socketFD; }
        if (!error && (fd < 0 || !FKSendFrame(fd, data))) error = FKUnixError(FKHelperTransportErrorUnknown, @"发送 IPC 帧失败", errno);
        if (!error) { response = FKReceiveFrame(fd); if (!response) error = FKUnixError(FKHelperTransportErrorTimeout, @"读取 IPC 响应失败或超时", errno); }
        if (error) { [self disconnect]; self.status.error = error; self.status.state = (error.code == FKHelperTransportErrorTimeout) ? FKHelperTransportStateTimeout : FKHelperTransportStateFailed; self.status.timestamp = [NSDate date]; }
        if (completion) completion(response, error);
    });
}
- (void)disconnect {
    @synchronized (self) { if (self.socketFD >= 0) { shutdown(self.socketFD, SHUT_RDWR); close(self.socketFD); self.socketFD = -1; } self.status.state = FKHelperTransportStateDisconnected; self.status.timestamp = [NSDate date]; self.observedPeerUID = (uid_t)-1; self.observedPeerPID = -1; }
}
@end

@interface FKHelperUnixSocketServer ()
@property (nonatomic, copy, readwrite) NSString *socketPath;
@property (nonatomic, assign) uid_t allowedPeerUID;
@property (nonatomic, assign) gid_t socketGroupID;
@property (nonatomic, assign) mode_t socketMode;
@property (nonatomic, copy) NSData * _Nullable (^handler)(NSData *, uid_t, pid_t);
@property (nonatomic, assign) int listenFD;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign, readwrite) BOOL running;
@end
@implementation FKHelperUnixSocketServer
- (instancetype)initWithSocketPath:(NSString *)socketPath allowedPeerUID:(uid_t)peerUID handler:(NSData *(^)(NSData *, uid_t, pid_t))handler {
    return [self initWithSocketPath:socketPath allowedPeerUID:peerUID socketGroupID:getgid() socketMode:0600 handler:handler];
}
- (instancetype)initWithSocketPath:(NSString *)socketPath allowedPeerUID:(uid_t)peerUID socketGroupID:(gid_t)groupID socketMode:(mode_t)mode handler:(NSData *(^)(NSData *, uid_t, pid_t))handler {
    self = [super init]; if (self) { _socketPath = [socketPath copy] ?: @""; _allowedPeerUID = peerUID; _socketGroupID = groupID; _socketMode = mode; _handler = [handler copy]; _listenFD = -1; _queue = dispatch_queue_create("com.filterkit.helper.unix-listener", DISPATCH_QUEUE_SERIAL); } return self;
}
- (BOOL)start:(NSError **)error {
    if (self.running) return YES;
    if (!FKUnixPathValid(self.socketPath) || !self.handler || (self.socketMode != 0600 && self.socketMode != 0660)) { if (error) *error = FKUnixError(FKHelperTransportErrorUnavailable, @"Listener 配置无效；Socket 权限仅允许 0600 或 0660", 0); return NO; }
    NSString *parent = [self.socketPath stringByDeletingLastPathComponent]; struct stat parentStat;
    if (lstat(parent.fileSystemRepresentation, &parentStat) != 0 || !S_ISDIR(parentStat.st_mode) || S_ISLNK(parentStat.st_mode) || parentStat.st_uid != getuid() || (parentStat.st_mode & 0022) != 0) { if (error) *error = FKUnixError(FKHelperTransportErrorIncompatible, @"Socket 父目录必须由当前用户拥有且不可被组/其他用户写入", errno); return NO; }
    struct stat existing; if (lstat(self.socketPath.fileSystemRepresentation, &existing) == 0) { if (!S_ISSOCK(existing.st_mode) || existing.st_uid != getuid() || unlink(self.socketPath.fileSystemRepresentation) != 0) { if (error) *error = FKUnixError(FKHelperTransportErrorIncompatible, @"拒绝覆盖非本进程所有的 Socket 路径", errno); return NO; } }
    int fd = socket(AF_UNIX, SOCK_STREAM, 0); if (fd < 0) { if (error) *error = FKUnixError(FKHelperTransportErrorUnknown, @"创建 Listener 失败", errno); return NO; }
    int yes = 1;
#ifdef SO_NOSIGPIPE
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
#endif
    struct sockaddr_un address; memset(&address, 0, sizeof(address)); address.sun_family = AF_UNIX; strlcpy(address.sun_path, self.socketPath.fileSystemRepresentation, sizeof(address.sun_path));
    if (bind(fd, (struct sockaddr *)&address, sizeof(address)) != 0 || chown(self.socketPath.fileSystemRepresentation, getuid(), self.socketGroupID) != 0 || chmod(self.socketPath.fileSystemRepresentation, self.socketMode) != 0 || listen(fd, 8) != 0) { int e = errno; close(fd); unlink(self.socketPath.fileSystemRepresentation); if (error) *error = FKUnixError(FKHelperTransportErrorUnknown, @"绑定或启动 Listener 失败", e); return NO; }
    self.listenFD = fd; self.running = YES;
    dispatch_async(self.queue, ^{ while (self.running) { int client = accept(fd, NULL, NULL); if (client < 0) { if (errno == EINTR) continue; if (!self.running) break; continue; }
        FKSetSocketTimeout(client, 5.0); uid_t uid = (uid_t)-1; gid_t gid = (gid_t)-1;
        if (getpeereid(client, &uid, &gid) == 0 && uid == self.allowedPeerUID) { while (self.running) { NSData *request = FKReceiveFrame(client); if (!request) break; NSData *response = self.handler(request, uid, -1); if (response.length == 0 || response.length > 1024 * 1024 || !FKSendFrame(client, response)) break; } }
        shutdown(client, SHUT_RDWR); close(client);
    } });
    return YES;
}
- (void)stop {
    if (!self.running) return; self.running = NO; int fd = self.listenFD; self.listenFD = -1; if (fd >= 0) { shutdown(fd, SHUT_RDWR); close(fd); }
    struct stat st; if (lstat(self.socketPath.fileSystemRepresentation, &st) == 0 && S_ISSOCK(st.st_mode) && st.st_uid == getuid()) unlink(self.socketPath.fileSystemRepresentation);
}
- (void)dealloc { [self stop]; }
@end
