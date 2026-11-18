#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Injector 配置只读快照状态。未读取到、不受支持与内部关联记录必须区分标注。
typedef NS_ENUM(NSInteger, FKConfigurationValidationStatus) {
    FKConfigurationValidationUnknown = 0,
    FKConfigurationValidationValid,
    FKConfigurationValidationIncomplete,
    FKConfigurationValidationInvalid,
    FKConfigurationValidationUnsupported,
    FKConfigurationValidationUnavailable
};

/// Injector 配置只读快照。仅记录受支持只读接口或已授权元数据；
/// 不修改 Injector 私有文件，不把 FilterKit 内部关联冒充为 Injector 实际配置。
@interface FKHelperConfigurationSnapshot : NSObject

@property (nonatomic, copy) NSString *snapshotID;
@property (nonatomic, copy, nullable) NSString *injectorID;
@property (nonatomic, copy) NSString *schemaVersion;
@property (nonatomic, copy) NSArray<NSDictionary *> *entries;
@property (nonatomic, strong) NSDate *capturedAt;
/// 读取来源：injector_readonly_provider / filesystem_metadata / filterkit_database / unsupported。
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy, nullable) NSString *sha256;
@property (nonatomic, assign) FKConfigurationValidationStatus validationStatus;

- (NSDictionary *)JSONDictionary;

+ (NSString *)validationStatusCode:(FKConfigurationValidationStatus)status;
+ (NSString *)validationStatusText:(FKConfigurationValidationStatus)status;
/// 是否为经只读接口确认的有效配置。
- (BOOL)isConfirmedValid;

@end

NS_ASSUME_NONNULL_END
