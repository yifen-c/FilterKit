#import "FKHelperTestTransport.h"

@interface FKHelperTestTransport ()
@property (nonatomic, strong) FKHelperTransportStatus *status;
@end

@implementation FKHelperTestTransport

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = [FKHelperTransportStatus new];
        _status.isMock = YES;
    }
    return self;
}

- (BOOL)connected {
    return NO; // Mock 永不报告为已连接。
}

- (BOOL)isMock {
    return YES;
}

- (NSError *)mockErrorForTimeout:(BOOL)timeout {
    FKHelperTransportErrorCode code = timeout ? FKHelperTransportErrorTimeout : FKHelperTransportErrorMock;
    NSString *description = timeout ? @"测试模拟传输超时" : @"测试模拟传输，并非真实 Helper 连接";
    return [NSError errorWithDomain:FKHelperTransportErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

- (void)connectWithCompletion:(void (^)(BOOL, NSError *_Nullable))completion {
    self.status.timestamp = [NSDate date];
    NSError *error = [self mockErrorForTimeout:self.simulateTimeout];
    self.status.state = self.simulateTimeout ? FKHelperTransportStateTimeout : FKHelperTransportStateFailed;
    self.status.error = error;
    if (completion) {
        completion(NO, error);
    }
}

- (void)sendData:(NSData *)data completion:(void (^)(NSData *_Nullable, NSError *_Nullable))completion {
    (void)data;
    self.status.timestamp = [NSDate date];
    NSError *error = [self mockErrorForTimeout:self.simulateTimeout];
    self.status.state = self.simulateTimeout ? FKHelperTransportStateTimeout : FKHelperTransportStateFailed;
    self.status.error = error;
    if (completion) {
        completion(nil, error);
    }
}

- (void)disconnect {
    self.status.state = FKHelperTransportStateDisconnected;
    self.status.timestamp = [NSDate date];
}

@end
