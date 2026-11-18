#import "FKJSONTests.h"
#import "FKEnvironmentEvidence.h"
#import "FKInjectorProfile.h"
#import "FKInjectorModel.h"
#import "FKSecurityEvent.h"

@implementation FKJSONTests

+ (NSUInteger)checkCount { return 7; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // 1. 空 / 非法字典入模型应返回 nil 或安全默认值，不抛异常。
    if ([FKEnvironmentEvidence evidenceFromDictionary:nil] != nil) [failures addObject:@"空字典证据应返回 nil"];
    if ([FKInjectorProfile profileFromDictionary:nil] != nil) [failures addObject:@"空字典画像应返回 nil"];
    if ([FKSecurityEvent eventFromDictionary:nil] != nil) [failures addObject:@"空字典事件应返回 nil"];

    // 2. 空注入器字典归为未识别，证据级别 unknown。
    FKInjectorModel *unknown = [FKInjectorModel modelFromDictionary:@{}];
    if (unknown.detected) [failures addObject:@"空注入器字典不应标记为已识别"];
    if (![unknown.evidenceLevel isEqualToString:@"unknown"]) [failures addObject:@"空注入器证据级别应为 unknown"];

    // 3. 证据 JSON 往返保留关键键。
    FKEnvironmentEvidence *evidence = [FKEnvironmentEvidence evidenceWithKey:@"jbroot"];
    evidence.path = @"/var/jb";
    evidence.exists = YES;
    evidence.readable = YES;
    NSDictionary *json = evidence.JSONDictionary;
    if (![json[@"key"] isEqualToString:@"jbroot"]) [failures addObject:@"证据 key 序列化丢失"];
    if (![json[@"readable"] boolValue]) [failures addObject:@"证据 readable 序列化错误"];

    return failures.copy;
}

@end
