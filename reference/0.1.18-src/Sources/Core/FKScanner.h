#import <Foundation/Foundation.h>
#import "FKModels.h"

@interface FKScanReport : NSObject
@property (nonatomic, copy) NSArray<FKTestResult *> *tests;
@property (nonatomic, strong) NSDictionary *environment;
@property (nonatomic, strong) NSArray<NSDictionary *> *apps;
@property (nonatomic, strong) NSDictionary *filesystem;
@property (nonatomic, strong) NSArray<NSDictionary *> *plugins;
@property (nonatomic, strong) NSDictionary *association;
/// 0.1.5 结构化环境评估（EnvironmentDetector 产出，证据保守派生）
@property (nonatomic, strong) NSDictionary *environmentAssessment;
/// 0.1.5 结构化注入器画像（InjectorDetector + Registry 画像产出）
@property (nonatomic, strong) NSDictionary *injectorAssessment;
/// 0.1.5 Helper 信任评估结论（TrustEvaluator 产出；未验证不提升为可信）
@property (nonatomic, strong) NSDictionary *helperTrust;
/// 0.1.5 安全审计报告（事件链 + 结构化快照）
@property (nonatomic, strong) NSDictionary *securityReport;
/// 0.1.5 自动化测试汇总（四套件实际执行结果）
@property (nonatomic, strong) NSDictionary *testSummary;
- (NSDictionary *)JSONDictionary;
@end

@interface FKScanner : NSObject
- (FKScanReport *)runScan;
@end
