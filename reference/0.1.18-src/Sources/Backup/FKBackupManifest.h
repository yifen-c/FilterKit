#import <Foundation/Foundation.h>

/// 单个被备份文件的元数据与摘要。元数据（权限/所有者/修改时间/链接信息）仅记录留档，0.1.2 不自动应用到系统文件。
@interface FKBackupFileEntry : NSObject

/// 原始越狱文件路径（只读来源）
@property (nonatomic, copy) NSString *originalPath;
/// 备份目录内相对路径（files/ 之下）
@property (nonatomic, copy) NSString *backupRelPath;
/// 文件字节大小
@property (nonatomic, assign) unsigned long long size;
/// 文件粗类型：mach_o / configuration / text / unknown
@property (nonatomic, copy) NSString *fileType;
/// 权限位（八进制字符串，如 100644）
@property (nonatomic, copy) NSString *mode;
/// 所有者只读记录（uid:gid）
@property (nonatomic, copy) NSString *owner;
/// 原始修改时间
@property (nonatomic, copy) NSDate *modificationDate;
/// 符号链接目标；普通文件为空
@property (nonatomic, copy) NSString *symlinkTarget;
/// 原始文件 MD5（对照 dpkg .md5sums）
@property (nonatomic, copy) NSString *md5;
/// 原始文件 SHA-256（备份一致性核对）
@property (nonatomic, copy) NSString *sha256;

- (NSDictionary *)JSONDictionary;
+ (instancetype)entryFromDictionary:(NSDictionary *)dict;

@end

/// 一次插件文件备份的清单：记录插件归属、操作类型、时间与全部文件条目。
@interface FKBackupManifest : NSObject

@property (nonatomic, copy) NSString *backupID;
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, copy) NSString *packageID;
/// 关联操作类型（enable / disable / validate / restore / backup）
@property (nonatomic, copy) NSString *operation;
@property (nonatomic, copy) NSDate *createdAt;
/// 备份格式版本
@property (nonatomic, copy) NSString *formatVersion;
@property (nonatomic, copy) NSArray<FKBackupFileEntry *> *files;

- (NSDictionary *)JSONDictionary;
+ (instancetype)manifestFromDictionary:(NSDictionary *)dict;

@end
