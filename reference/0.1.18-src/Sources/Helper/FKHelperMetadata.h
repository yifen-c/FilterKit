#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper 候选元数据：只记录本地只读采集到的文件形态与归属信息，不构成身份可信结论。
@interface FKHelperMetadata : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy, nullable) NSString *logicalPath;
@property (nonatomic, assign) BOOL exists;
@property (nonatomic, assign) BOOL regularFile;
@property (nonatomic, assign) BOOL executable;
@property (nonatomic, assign) BOOL readable;
@property (nonatomic, assign) long long size;
@property (nonatomic, copy) NSArray<NSString *> *packageIDs;
@property (nonatomic, copy, nullable) NSString *version;
@property (nonatomic, copy, nullable) NSString *identifier;
@property (nonatomic, assign) NSInteger protocolVersion;
@property (nonatomic, copy) NSArray<NSString *> *missingFields;
@property (nonatomic, copy) NSArray<NSString *> *validationIssues;
@property (nonatomic, copy) NSString *fileType;
@property (nonatomic, assign) BOOL pathIsAbsolute;
@property (nonatomic, assign) BOOL pathHasTraversal;
@property (nonatomic, assign) BOOL candidateSchemaValid;
@property (nonatomic, assign) BOOL systemToolCandidate;

+ (instancetype)metadataFromCandidate:(NSDictionary *)candidate;
- (NSDictionary *)JSONDictionary;
@end

NS_ASSUME_NONNULL_END
