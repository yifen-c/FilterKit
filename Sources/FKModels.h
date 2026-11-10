#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FKTestState) {
    FKTestStateUnknown = 0,
    FKTestStatePassed,
    FKTestStateFailed
};

@interface FKTestResult : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic) FKTestState state;
@property (nonatomic, strong) NSDictionary *payload;
+ (instancetype)resultWithID:(NSString *)identifier title:(NSString *)title state:(FKTestState)state detail:(NSString *)detail payload:(NSDictionary *)payload;
- (NSDictionary *)JSONDictionary;
@end
