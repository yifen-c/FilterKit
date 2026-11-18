#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 插件只读检查状态。Readable 仅表示元数据可读，不代表插件安全、可注入或已启用。
typedef NS_ENUM(NSInteger, FKPluginInspectionStatus) {
    FKPluginInspectionUnknown = 0,
    FKPluginInspectionReadable,
    FKPluginInspectionIncomplete,
    FKPluginInspectionInvalid,
    FKPluginInspectionUnsupported
};

/// 插件只读信息（来自真实读取来源或 FilterKit 自身记录）。推断来源不得冒充真实设备清单。
@interface FKHelperPluginInfo : NSObject

@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *filename;
/// 读取来源：injector_api / filesystem_metadata / filterkit_database / inferred / unknown。
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy, nullable) NSString *architecture;
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, copy, nullable) NSString *sha256;
@property (nonatomic, copy, nullable) NSString *bundleID;
@property (nonatomic, copy, nullable) NSString *injectorID;
@property (nonatomic, assign) FKPluginInspectionStatus inspectionStatus;
@property (nonatomic, copy, nullable) NSString *evidenceSource;

- (NSDictionary *)JSONDictionary;

+ (NSString *)inspectionStatusCode:(FKPluginInspectionStatus)status;
+ (NSString *)inspectionStatusText:(FKPluginInspectionStatus)status;
/// 是否为真实读取来源（排除 inferred / unknown）。
- (BOOL)isFromRealReadSource;

@end

NS_ASSUME_NONNULL_END
