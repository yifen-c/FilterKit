#import "FKHelperUnixSocketTransportTests.h"
#import "FKHelperUnixSocketTransport.h"
#import "FKHelperTransportState.h"
#import <unistd.h>

@implementation FKHelperUnixSocketTransportTests
+ (NSUInteger)checkCount { return 9; }
+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"fk%d.sock", getpid()]];
    FKHelperUnixSocketServer *server = [[FKHelperUnixSocketServer alloc] initWithSocketPath:path allowedPeerUID:getuid() handler:^NSData *(NSData *request, uid_t uid, pid_t pid) {
        (void)uid; (void)pid; return request;
    }];
    NSError *startError = nil;
    BOOL started = [server start:&startError];
    if (!started) [failures addObject:@"USK1801 临时 Unix Socket Listener 应可启动"];
    FKHelperUnixSocketTransport *client = [[FKHelperUnixSocketTransport alloc] initWithSocketPath:path expectedPeerUID:getuid() timeout:3.0];
    dispatch_semaphore_t connected = dispatch_semaphore_create(0); __block BOOL connectOK = NO; __block NSError *connectError = nil;
    [client connectWithCompletion:^(BOOL success, NSError *error) { connectOK = success; connectError = error; dispatch_semaphore_signal(connected); }];
    long connectWait = dispatch_semaphore_wait(connected, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC));
    if (connectWait != 0 || !connectOK || !client.connected) [failures addObject:[NSString stringWithFormat:@"USK1802 Socket 连接或 Peer UID 验证失败：%@", connectError.localizedDescription ?: @"timeout"]];
    if (client.isMock) [failures addObject:@"USK1803 真实 Socket 适配器不得标记 Mock"];
    if (client.observedPeerUID != getuid()) [failures addObject:@"USK1804 应记录并匹配 getpeereid 返回的 Peer UID"];
    uid_t wrongUID = getuid() == (uid_t)-1 ? (uid_t)1 : (uid_t)(getuid() + 1);
    FKHelperUnixSocketTransport *wrongPeer = [[FKHelperUnixSocketTransport alloc] initWithSocketPath:path expectedPeerUID:wrongUID timeout:2.0];
    dispatch_semaphore_t wrongPeerDone = dispatch_semaphore_create(0); __block BOOL wrongPeerOK = YES;
    [wrongPeer connectWithCompletion:^(BOOL success, NSError *error) { (void)error; wrongPeerOK = success; dispatch_semaphore_signal(wrongPeerDone); }];
    dispatch_semaphore_wait(wrongPeerDone, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    if (wrongPeerOK) [failures addObject:@"USK1805 Peer UID 不匹配必须拒绝连接"];
    [wrongPeer disconnect];
    NSData *request = [@"FilterKit IPC 0.1.18" dataUsingEncoding:NSUTF8StringEncoding];
    dispatch_semaphore_t replied = dispatch_semaphore_create(0); __block NSData *response = nil; __block NSError *sendError = nil;
    [client sendData:request completion:^(NSData *data, NSError *error) { response = data; sendError = error; dispatch_semaphore_signal(replied); }];
    long replyWait = dispatch_semaphore_wait(replied, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC));
    if (replyWait != 0 || ![response isEqualToData:request]) [failures addObject:[NSString stringWithFormat:@"USK1806 长度前缀请求/响应往返失败：%@", sendError.localizedDescription ?: @"timeout"]];
    NSData *oversized = [NSMutableData dataWithLength:1024 * 1024 + 1];
    dispatch_semaphore_t rejected = dispatch_semaphore_create(0); __block NSError *oversizeError = nil;
    [client sendData:oversized completion:^(NSData *data, NSError *error) { (void)data; oversizeError = error; dispatch_semaphore_signal(rejected); }];
    dispatch_semaphore_wait(rejected, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC));
    if (!oversizeError) [failures addObject:@"USK1807 超过 1 MiB 的请求必须拒绝"];
    [client disconnect]; if (client.connected || client.status.state != FKHelperTransportStateDisconnected) [failures addObject:@"USK1808 disconnect 必须撤销连接状态"];
    FKHelperUnixSocketTransport *missing = [[FKHelperUnixSocketTransport alloc] initWithSocketPath:[path stringByAppendingString:@".missing"] expectedPeerUID:getuid() timeout:1.0];
    dispatch_semaphore_t missingDone = dispatch_semaphore_create(0); __block BOOL missingOK = YES;
    [missing connectWithCompletion:^(BOOL success, NSError *error) { (void)error; missingOK = success; dispatch_semaphore_signal(missingDone); }];
    dispatch_semaphore_wait(missingDone, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    if (missingOK) [failures addObject:@"USK1809 不存在的 Endpoint 不得报告连接成功"];
    [missing disconnect]; [server stop];
    return failures.copy;
}
@end
