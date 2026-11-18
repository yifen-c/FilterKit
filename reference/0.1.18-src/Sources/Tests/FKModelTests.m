#import "FKModelTests.h"
#import "FKManageModels.h"
#import "FKOperationModels.h"

@implementation FKModelTests

+ (NSUInteger)checkCount { return 5; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // 1. 插件模型字典构建后 JSON 往返保留关键字段。
    NSDictionary *raw = @{
        @"PluginID": @"com.test.example:example",
        @"Name": @"ExamplePlugin",
        @"Version": @"1.0.0",
        @"PackageID": @"com.test.example",
        @"DylibPath": @"/var/jb/usr/lib/example.dylib",
        @"PlistPath": @"/var/jb/Library/Preferences/example.plist"
    };
    FKPluginModel *plugin = [FKPluginModel modelWithDictionary:raw];
    NSDictionary *pluginJSON = plugin.JSONDictionary;
    if (![pluginJSON[@"plugin_id"] isEqualToString:@"com.test.example:example"]) [failures addObject:@"插件 plugin_id 序列化丢失"];
    if (![pluginJSON[@"name"] isEqualToString:@"ExamplePlugin"]) [failures addObject:@"插件 name 序列化丢失"];

    // 2. Filter 规则 Bundles 解析。
    FKFilterModel *filter = [FKFilterModel modelWithDictionary:@{@"bundle_ids": @[@"com.app1", @"com.app2"]}
                                                    filterPath:@"/var/jb/Library/Preferences/example.plist"];
    if (filter.bundles.count != 2) [failures addObject:@"Filter Bundles 解析数量错误"];

    // 3. 操作请求序列化保留插件与操作类型。
    FKOperationRequest *request = [FKOperationRequest requestWithPluginID:plugin.pluginID operation:FKOperationTypeValidate];
    NSDictionary *requestJSON = request.JSONDictionary;
    if (![requestJSON[@"plugin_id"] isEqualToString:plugin.pluginID]) [failures addObject:@"操作请求 plugin_id 序列化丢失"];
    if (![requestJSON[@"operation"] isEqualToString:@"validate"]) [failures addObject:@"操作请求 operation 序列化错误"];

    return failures.copy;
}

@end
