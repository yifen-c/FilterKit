#import "FKEnvironmentValidator.h"

@implementation FKEnvironmentValidator

+ (FKCompatibilityStatus)evaluateWithTypeCode:(NSString *)typeCode
                                jbrootDetected:(BOOL)jbrootDetected
                                 jbrootReadable:(BOOL)jbrootReadable
                            injectorIdentified:(BOOL)injectorIdentified
                                     supported:(BOOL)supported
                                       reasons:(NSMutableArray<NSString *> *)reasons {
    BOOL rootKnown = [typeCode isEqualToString:@"roothide"] || [typeCode isEqualToString:@"rootless"];

    // 不在支持范围：架构 / 系统明确不支持受控管理。
    if (!supported) {
        [reasons addObject:@"当前环境不在受控管理支持范围"];
        return FKCompatibilityStatusUnsupported;
    }
    // 越狱类型未识别：证据不足，不能判 Passed。
    if (!rootKnown) {
        [reasons addObject:@"未取得有效的越狱类型证据"];
        return FKCompatibilityStatusUnknown;
    }
    // 根目录未定位：证据不足。
    if (!jbrootDetected) {
        [reasons addObject:@"未定位到有效的 JBROOT 路径"];
        return FKCompatibilityStatusUnknown;
    }
    // 路径不可读：可能是沙盒权限或路径映射差异，保守归 Partial，不直接判环境不兼容。
    if (!jbrootReadable) {
        [reasons addObject:@"JBROOT 路径不可读，可能受沙盒权限或路径映射限制"];
        return FKCompatibilityStatusPartial;
    }
    // 根目录可读但注入器未识别：部分证据不足。
    if (!injectorIdentified) {
        [reasons addObject:@"根目录已定位，但未识别到注入器"];
        return FKCompatibilityStatusPartial;
    }
    [reasons addObject:@"根目录与注入器均已取得证据"];
    return FKCompatibilityStatusPassed;
}

@end
