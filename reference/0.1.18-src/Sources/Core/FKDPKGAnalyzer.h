#import <Foundation/Foundation.h>

@interface FKDPKGAnalyzer : NSObject
+ (NSDictionary *)analyzeStatusAtPath:(NSString *)statusPath
                           selectedRoot:(NSString *)selectedRoot
                               packages:(NSArray<NSDictionary *> *)packages
                                 dylibs:(NSArray<NSDictionary *> *)dylibs
                                  plists:(NSArray<NSDictionary *> *)plists;
@end
