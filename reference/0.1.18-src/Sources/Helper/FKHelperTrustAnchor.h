#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 发布签名公钥锚点。测试锚点永远不能用于生产放行。
@interface FKHelperTrustAnchor : NSObject
@property (nonatomic, copy, readonly) NSString *keyID;
@property (nonatomic, copy, readonly) NSString *algorithm;
@property (nonatomic, copy, readonly) NSData *publicKeyData;
@property (nonatomic, copy, readonly) NSString *environment;
/// 仅由未来受审查的内置锚点加载器设置；公开构造器固定为 caller_supplied。
@property (nonatomic, copy, readonly) NSString *provisioningSource;
@property (nonatomic, assign, readonly, getter=isTestOnly) BOOL testOnly;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable instancetype)initWithKeyID:(NSString *)keyID
                             algorithm:(NSString *)algorithm
                         publicKeyData:(NSData *)publicKeyData
                           environment:(NSString *)environment
                              testOnly:(BOOL)testOnly NS_DESIGNATED_INITIALIZER;
- (BOOL)isStructurallyValid;
- (BOOL)isUsableForProduction;
- (NSDictionary *)JSONDictionary;
@end

/// 进程内只读锚点仓库；默认不内置任何生产公钥。
@interface FKHelperTrustAnchorStore : NSObject
@property (nonatomic, copy, readonly) NSString *policyVersion;
@property (nonatomic, copy, readonly) NSArray<FKHelperTrustAnchor *> *anchors;
- (instancetype)init;
- (instancetype)initWithAnchors:(NSArray<FKHelperTrustAnchor *> *)anchors;
- (nullable FKHelperTrustAnchor *)anchorForKeyID:(NSString *)keyID;
- (nullable FKHelperTrustAnchor *)productionAnchorForKeyID:(NSString *)keyID;
- (BOOL)hasProductionAnchor;
- (NSDictionary *)JSONDictionary;
@end

NS_ASSUME_NONNULL_END
