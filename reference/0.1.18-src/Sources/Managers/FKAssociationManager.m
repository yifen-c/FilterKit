#import "FKAssociationManager.h"

static const NSUInteger FKAssociationSchemaVersion = 1;
/// 最近使用列表上限。
static const NSUInteger FKRecentAppLimit = 20;

@interface FKAssociationManager ()
@property (nonatomic, strong) NSMutableArray<FKAppPluginAssociation *> *mutableAssociations;
@property (nonatomic, strong) NSMutableSet<NSString *> *favoriteSet;
@property (nonatomic, strong) NSMutableArray<NSString *> *mutableRecentApps;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *lastPersistError;
@property (nonatomic, strong) NSURL *relationsDirURL;
@property (nonatomic, strong) NSURL *associationsURL;
@property (nonatomic, strong) NSURL *favoritesURL;
@property (nonatomic, strong) NSURL *recentURL;
@property (nonatomic, strong) dispatch_queue_t persistQueue;
@end

@implementation FKAssociationManager

- (instancetype)init {
    if ((self = [super init])) {
        _mutableAssociations = [NSMutableArray array];
        _favoriteSet = [NSMutableSet set];
        _mutableRecentApps = [NSMutableArray array];
        _lock = [NSLock new];
        _schemaVersion = FKAssociationSchemaVersion;
        _persistQueue = dispatch_queue_create("com.filterkit.relations.persist", DISPATCH_QUEUE_SERIAL);
        [self resolvePersistenceURLs];
        [self loadPersistedData];
    }
    return self;
}

#pragma mark - 持久化路径与加载

- (void)resolvePersistenceURLs {
    NSURL *appSupport = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                 inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [appSupport URLByAppendingPathComponent:@"FilterKit/Relations" isDirectory:YES];
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) self.lastPersistError = error.localizedDescription;
    self.relationsDirURL = dir;
    self.associationsURL = [dir URLByAppendingPathComponent:@"associations.json"];
    self.favoritesURL = [dir URLByAppendingPathComponent:@"favorites.json"];
    self.recentURL = [dir URLByAppendingPathComponent:@"recent_apps.json"];
}

/// 启动加载三类持久化数据；任一文件损坏单独隔离，不影响其余历史。
- (void)loadPersistedData {
    [self loadAssociations];
    [self loadFavorites];
    [self loadRecentApps];
}

- (void)loadAssociations {
    NSData *data = [NSData dataWithContentsOfURL:self.associationsURL];
    if (data.length == 0) return;
    NSError *parseError = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    NSArray *raw = [payload isKindOfClass:NSDictionary.class] ? payload[@"associations"] : nil;
    if (parseError || ![raw isKindOfClass:NSArray.class]) {
        [self isolateCorruptedFile:self.associationsURL reason:parseError.localizedDescription ?: @"关联记录结构非法"];
        return;
    }
    NSMutableArray<FKAppPluginAssociation *> *loaded = [NSMutableArray array];
    for (id item in raw) {
        FKAppPluginAssociation *association = [FKAppPluginAssociation associationFromDictionary:item];
        if (association) [loaded addObject:association];
    }
    [self.lock lock];
    [self.mutableAssociations addObjectsFromArray:loaded];
    [self.lock unlock];
}

- (void)loadFavorites {
    NSData *data = [NSData dataWithContentsOfURL:self.favoritesURL];
    if (data.length == 0) return;
    NSError *parseError = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    NSArray *raw = [payload isKindOfClass:NSDictionary.class] ? payload[@"favorites"] : nil;
    if (parseError || ![raw isKindOfClass:NSArray.class]) {
        [self isolateCorruptedFile:self.favoritesURL reason:parseError.localizedDescription ?: @"收藏记录结构非法"];
        return;
    }
    NSMutableSet<NSString *> *loaded = [NSMutableSet set];
    for (id item in raw) {
        if ([item isKindOfClass:NSString.class] && [(NSString *)item length]) [loaded addObject:item];
    }
    [self.lock lock];
    [self.favoriteSet unionSet:loaded];
    [self.lock unlock];
}

- (void)loadRecentApps {
    NSData *data = [NSData dataWithContentsOfURL:self.recentURL];
    if (data.length == 0) return;
    NSError *parseError = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    NSArray *raw = [payload isKindOfClass:NSDictionary.class] ? payload[@"recent"] : nil;
    if (parseError || ![raw isKindOfClass:NSArray.class]) {
        [self isolateCorruptedFile:self.recentURL reason:parseError.localizedDescription ?: @"最近使用记录结构非法"];
        return;
    }
    NSMutableArray<NSString *> *loaded = [NSMutableArray array];
    for (id item in raw) {
        if ([item isKindOfClass:NSString.class] && [(NSString *)item length] && ![loaded containsObject:item]) {
            [loaded addObject:item];
        }
    }
    [self.lock lock];
    self.mutableRecentApps = loaded;
    [self.lock unlock];
}

/// 损坏文件改名隔离，保留现场；不删除、不覆盖历史。
- (void)isolateCorruptedFile:(NSURL *)fileURL reason:(NSString *)reason {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    NSString *stamp = [[formatter stringFromDate:[NSDate date]] stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    NSString *base = fileURL.lastPathComponent.stringByDeletingPathExtension;
    NSURL *backup = [fileURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:
                     [NSString stringWithFormat:@"%@.corrupted-%@.json", base, stamp]];
    NSError *error = nil;
    [[NSFileManager defaultManager] moveItemAtURL:fileURL toURL:backup error:&error];
    self.lastPersistError = [NSString stringWithFormat:@"%@ 已隔离：%@", base, reason ?: @"结构非法"];
}

#pragma mark - 管理关系

- (NSArray<FKAppPluginAssociation *> *)allAssociations {
    [self.lock lock];
    NSArray<FKAppPluginAssociation *> *sorted = [self.mutableAssociations sortedArrayUsingComparator:^NSComparisonResult(FKAppPluginAssociation *a, FKAppPluginAssociation *b) {
        NSDate *ta = a.createdAt ?: [NSDate date];
        NSDate *tb = b.createdAt ?: [NSDate date];
        return [ta compare:tb];
    }];
    [self.lock unlock];
    return sorted;
}

- (NSArray<FKAppPluginAssociation *> *)associationsForApp:(NSString *)appBundleID {
    if (!appBundleID.length) return @[];
    return [self.allAssociations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"appBundleID == %@", appBundleID]];
}

- (NSArray<FKAppPluginAssociation *> *)associationsForPlugin:(NSString *)pluginID {
    if (!pluginID.length) return @[];
    return [self.allAssociations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pluginID == %@", pluginID]];
}

- (nullable FKAppPluginAssociation *)associationForApp:(NSString *)appBundleID plugin:(NSString *)pluginID {
    if (!appBundleID.length || !pluginID.length) return nil;
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"appBundleID == %@ AND pluginID == %@", appBundleID, pluginID];
    return [self.allAssociations filteredArrayUsingPredicate:pred].firstObject;
}

- (BOOL)hasAssociationForApp:(NSString *)appBundleID plugin:(NSString *)pluginID {
    return [self associationForApp:appBundleID plugin:pluginID] != nil;
}

- (nullable FKAppPluginAssociation *)addAssociationForApp:(NSString *)appBundleID plugin:(NSString *)pluginID {
    if (!appBundleID.length || !pluginID.length) return nil;
    if ([self hasAssociationForApp:appBundleID plugin:pluginID]) return nil;

    NSDate *now = [NSDate date];
    FKAppPluginAssociation *association = [FKAppPluginAssociation new];
    association.associationID = [NSUUID UUID].UUIDString;
    association.appBundleID = appBundleID;
    association.pluginID = pluginID;
    association.createdAt = now;
    association.updatedAt = now;
    association.source = FKAssociationSourceManual;
    association.status = FKAssociationStatusAssociated;

    [self.lock lock];
    [self.mutableAssociations addObject:association];
    [self.lock unlock];
    [self persistAssociations];
    return association;
}

- (BOOL)removeAssociationForApp:(NSString *)appBundleID plugin:(NSString *)pluginID {
    FKAppPluginAssociation *existing = [self associationForApp:appBundleID plugin:pluginID];
    if (!existing) return NO;
    [self.lock lock];
    [self.mutableAssociations removeObject:existing];
    [self.lock unlock];
    [self persistAssociations];
    return YES;
}

#pragma mark - 收藏

- (NSArray<NSString *> *)favoriteApps {
    [self.lock lock];
    NSArray<NSString *> *favorites = self.favoriteSet.allObjects;
    [self.lock unlock];
    return [favorites sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (BOOL)isFavoriteApp:(NSString *)appBundleID {
    if (!appBundleID.length) return NO;
    [self.lock lock];
    BOOL favorite = [self.favoriteSet containsObject:appBundleID];
    [self.lock unlock];
    return favorite;
}

- (BOOL)toggleFavoriteApp:(NSString *)appBundleID {
    if (!appBundleID.length) return NO;
    [self.lock lock];
    BOOL favorite;
    if ([self.favoriteSet containsObject:appBundleID]) {
        [self.favoriteSet removeObject:appBundleID];
        favorite = NO;
    } else {
        [self.favoriteSet addObject:appBundleID];
        favorite = YES;
    }
    [self.lock unlock];
    [self persistFavorites];
    return favorite;
}

#pragma mark - 最近使用

- (NSArray<NSString *> *)recentApps {
    [self.lock lock];
    NSArray<NSString *> *recent = self.mutableRecentApps.copy;
    [self.lock unlock];
    return recent;
}

- (void)recordRecentApp:(NSString *)appBundleID {
    if (!appBundleID.length) return;
    [self.lock lock];
    [self.mutableRecentApps removeObject:appBundleID];
    [self.mutableRecentApps insertObject:appBundleID atIndex:0];
    if (self.mutableRecentApps.count > FKRecentAppLimit) {
        [self.mutableRecentApps removeObjectsInRange:NSMakeRange(FKRecentAppLimit, self.mutableRecentApps.count - FKRecentAppLimit)];
    }
    [self.lock unlock];
    [self persistRecentApps];
}

#pragma mark - 持久化写入

- (void)persistAssociations {
    NSArray<FKAppPluginAssociation *> *snapshot = self.allAssociations;
    NSArray *items = [snapshot valueForKey:@"JSONDictionary"];
    NSDictionary *payload = @{@"schema_version": @(FKAssociationSchemaVersion), @"associations": items};
    dispatch_async(self.persistQueue, ^{ [self writePayload:payload toURL:self.associationsURL]; });
}

- (void)persistFavorites {
    NSDictionary *payload = @{@"schema_version": @(FKAssociationSchemaVersion), @"favorites": self.favoriteApps};
    dispatch_async(self.persistQueue, ^{ [self writePayload:payload toURL:self.favoritesURL]; });
}

- (void)persistRecentApps {
    NSDictionary *payload = @{@"schema_version": @(FKAssociationSchemaVersion), @"recent": self.recentApps};
    dispatch_async(self.persistQueue, ^{ [self writePayload:payload toURL:self.recentURL]; });
}

/// 原子写入；失败保留内存数据，仅记录错误，不覆盖损坏文件。
- (void)writePayload:(NSDictionary *)payload toURL:(NSURL *)url {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&error];
    if (data && [data writeToURL:url options:NSDataWritingAtomic error:&error]) {
        self.lastPersistError = nil;
    } else {
        self.lastPersistError = error.localizedDescription ?: @"关系数据写入失败";
    }
}

#pragma mark - 导出与状态

- (NSDictionary *)JSONDictionary {
    return @{
        @"associations": [self.allAssociations valueForKey:@"JSONDictionary"],
        @"favorites": self.favoriteApps,
        @"recent_apps": self.recentApps
    };
}

- (NSDictionary *)persistenceStatus {
    return @{
        @"schema_version": @(FKAssociationSchemaVersion),
        @"association_count": @(self.allAssociations.count),
        @"favorite_count": @(self.favoriteApps.count),
        @"recent_count": @(self.recentApps.count),
        @"last_persist_error": self.lastPersistError ?: @""
    };
}

@end
