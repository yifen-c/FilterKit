#import <Foundation/Foundation.h>
#import "FKEnvironmentCompatibility.h"
#import "FKEnvironmentEvidence.h"

/// 最终环境信息：汇总越狱类型、JBROOT、注入器、兼容性结论与各项证据。
/// 结论由证据派生，不沿用上一次扫描结果推断当前状态。
@interface FKEnvironmentModel : NSObject

/// 越狱类型码（roothide / rootless / unknown）
@property (nonatomic, copy) NSString *jailbreakTypeCode;
/// 越狱类型展示名
@property (nonatomic, copy) NSString *jailbreakDisplayName;
/// 定位到的 JBROOT 路径；未定位到为空
@property (nonatomic, copy) NSString *jbrootPath;
/// 是否检测到 JBROOT 路径
@property (nonatomic, assign) BOOL jbrootDetected;
/// 识别到的注入器标识；未识别到为空
@property (nonatomic, copy) NSString *injectorName;
/// 注入器版本；未识别到为空
@property (nonatomic, copy) NSString *injectorVersion;
/// 兼容性结论
@property (nonatomic, assign) FKCompatibilityStatus compatibility;
/// 兼容性原因列表
@property (nonatomic, copy) NSArray<NSString *> *compatibilityReasons;
/// 各项证据，键为证据项标识
@property (nonatomic, copy) NSDictionary<NSString *, FKEnvironmentEvidence *> *evidence;
/// 原始扫描环境字典（保留未归类字段，供备份与详情查看）
@property (nonatomic, strong) NSDictionary *rawEnvironment;

- (NSDictionary *)JSONDictionary;

@end
