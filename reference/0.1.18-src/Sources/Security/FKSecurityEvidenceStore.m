#import "FKSecurityEvidenceStore.h"

@interface FKSecurityEvidenceStore ()
@property (nonatomic, strong) NSMutableArray<FKSecurityEvent *> *mutableEvents;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation FKSecurityEvidenceStore

- (instancetype)init {
    if ((self = [super init])) {
        _mutableEvents = [NSMutableArray array];
        _lock = [NSLock new];
    }
    return self;
}

- (void)appendEvent:(FKSecurityEvent *)event {
    if (![event isKindOfClass:FKSecurityEvent.class]) return;
    [self.lock lock];
    [self.mutableEvents addObject:event];
    [self.lock unlock];
}

- (NSArray<FKSecurityEvent *> *)events {
    [self.lock lock];
    NSArray *snapshot = self.mutableEvents.copy;
    [self.lock unlock];
    return snapshot;
}

- (NSArray<FKSecurityEvent *> *)eventsForType:(NSString *)typeCode {
    if (typeCode.length == 0) return @[];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"eventType == %@", typeCode];
    return [self.events filteredArrayUsingPredicate:predicate];
}

- (FKSecurityEvent *)eventForID:(NSString *)eventID {
    if (eventID.length == 0) return nil;
    for (FKSecurityEvent *event in self.events) {
        if ([event.eventID isEqualToString:eventID]) return event;
    }
    return nil;
}

- (void)reset {
    [self.lock lock];
    [self.mutableEvents removeAllObjects];
    [self.lock unlock];
}

@end
