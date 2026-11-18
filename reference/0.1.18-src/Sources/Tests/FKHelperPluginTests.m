#import "FKHelperPluginTests.h"
#import "FKHelperPluginInfo.h"

@implementation FKHelperPluginTests

+ (NSUInteger)checkCount { return 12; }

+ (NSArray<NSString *> *)runChecks {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // PLG901：默认状态 Unknown。
    FKHelperPluginInfo *p = [FKHelperPluginInfo new];
    if (p.inspectionStatus != FKPluginInspectionUnknown) [failures addObject:@"PLG901 默认应为 Unknown"];

    // PLG902：元数据可读 → Readable。
    p.inspectionStatus = FKPluginInspectionReadable;
    if (p.inspectionStatus != FKPluginInspectionReadable) [failures addObject:@"PLG902 应标记 Readable"];

    // PLG903：元数据不完整 → Incomplete。
    FKHelperPluginInfo *p3 = [FKHelperPluginInfo new];
    p3.inspectionStatus = FKPluginInspectionIncomplete;
    if (p3.inspectionStatus != FKPluginInspectionIncomplete) [failures addObject:@"PLG903 应标记 Incomplete"];

    // PLG904：信息无效 → Invalid。
    FKHelperPluginInfo *p4 = [FKHelperPluginInfo new];
    p4.inspectionStatus = FKPluginInspectionInvalid;
    if (p4.inspectionStatus != FKPluginInspectionInvalid) [failures addObject:@"PLG904 应标记 Invalid"];

    // PLG905：来源不受支持 → Unsupported。
    FKHelperPluginInfo *p5 = [FKHelperPluginInfo new];
    p5.inspectionStatus = FKPluginInspectionUnsupported;
    if (p5.inspectionStatus != FKPluginInspectionUnsupported) [failures addObject:@"PLG905 应标记 Unsupported"];

    // PLG906：injector_api 为真实读取来源。
    FKHelperPluginInfo *p6 = [FKHelperPluginInfo new];
    p6.source = @"injector_api";
    if (!p6.isFromRealReadSource) [failures addObject:@"PLG906 injector_api 应计为真实读取"];

    // PLG907：filesystem_metadata 为真实读取来源。
    FKHelperPluginInfo *p7 = [FKHelperPluginInfo new];
    p7.source = @"filesystem_metadata";
    if (!p7.isFromRealReadSource) [failures addObject:@"PLG907 filesystem_metadata 应计为真实读取"];

    // PLG908：inferred 不算真实读取。
    FKHelperPluginInfo *p8 = [FKHelperPluginInfo new];
    p8.source = @"inferred";
    if (p8.isFromRealReadSource) [failures addObject:@"PLG908 inferred 不得计为真实读取"];

    // PLG909：filterkit_database 不算设备真实清单。
    FKHelperPluginInfo *p9 = [FKHelperPluginInfo new];
    p9.source = @"filterkit_database";
    if (p9.isFromRealReadSource) [failures addObject:@"PLG909 自身关联记录不得冒充真实清单"];

    // PLG910：JSON 含标识 / 状态 / 来源。
    FKHelperPluginInfo *p10 = [FKHelperPluginInfo new];
    p10.pluginID = @"com.example.plugin";
    p10.source = @"injector_api";
    NSDictionary *json = p10.JSONDictionary;
    if (![json[@"pluginID"] isEqualToString:@"com.example.plugin"] || !json[@"inspectionStatus"] || !json[@"source"]) {
        [failures addObject:@"PLG910 JSON 字段不完整"];
    }

    // PLG911：Readable 模型不含启用 / 注入结论字段。
    if ([json.allKeys containsObject:@"enabled"] || [json.allKeys containsObject:@"injected"]) {
        [failures addObject:@"PLG911 只读模型不得携带启用 / 注入结论"];
    }

    // PLG912：无摘要时为空串，不臆造 SHA256。
    if (p10.sha256.length != 0 || ![json[@"sha256"] isEqualToString:@""]) [failures addObject:@"PLG912 无摘要应为空串"];

    return failures.copy;
}

@end
