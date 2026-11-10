#import <Foundation/Foundation.h>
#import "FKModels.h"

@interface FKScanReport : NSObject
@property (nonatomic, copy) NSArray<FKTestResult *> *tests;
@property (nonatomic, strong) NSDictionary *environment;
@property (nonatomic, strong) NSArray<NSDictionary *> *apps;
@property (nonatomic, strong) NSDictionary *filesystem;
- (NSDictionary *)JSONDictionary;
@end

@interface FKScanner : NSObject
- (FKScanReport *)runScan;
@end
