#import "FKScanner.h"
#import "FKDPKGAnalyzer.h"
#import "FKEnvironmentCompatibility.h"
#import "FKEnvironmentDetector.h"
#import "FKInjectorDetector.h"
#import "FKInjectorRegistry.h"
#import "FKInjectorProfile.h"
#import "FKHelperServiceDiscovery.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <dirent.h>
#import <errno.h>
#import <unistd.h>
#import <string.h>
#import <stdlib.h>
#import <limits.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

#if __has_include(<roothide.h>)
#import <roothide.h>
#define FK_HAS_ROOTHIDE_API 1
#else
#define FK_HAS_ROOTHIDE_API 0
#endif

static NSString * const FKVersion = @"0.1.18";

// 环境兼容性枚举与状态码/文案见共享头 FKEnvironmentCompatibility.h。

static NSString *FKErrnoName(int value) {
    switch (value) {
        case 0: return @"成功";
        case ENOENT: return @"路径不存在";
        case EACCES: return @"权限拒绝";
        case EPERM: return @"操作不允许";
        case ENOTDIR: return @"路径组件不是目录";
        case ELOOP: return @"符号链接循环";
        case EIO: return @"I/O 错误";
        case ENAMETOOLONG: return @"路径过长";
        case EROFS: return @"只读文件系统";
        default: return [NSString stringWithFormat:@"系统错误（errno=%d）", value];
    }
}

static NSDictionary *FKPathProbe(NSString *path) {
    if (![path isKindOfClass:NSString.class] || path.length == 0) path = @"";
    const char *fsPath = path.fileSystemRepresentation;
    struct stat lst = {0}, st = {0};
    errno = 0;
    BOOL lstatOK = lstat(fsPath, &lst) == 0;
    int lstatErr = lstatOK ? 0 : errno;
    errno = 0;
    BOOL statOK = stat(fsPath, &st) == 0;
    int statErr = statOK ? 0 : errno;
    BOOL isSymlink = lstatOK && S_ISLNK(lst.st_mode);
    BOOL isDirectory = statOK && S_ISDIR(st.st_mode);
    errno = 0;
    BOOL readable = access(fsPath, R_OK) == 0;
    int accessErr = readable ? 0 : errno;
    NSInteger entryCount = -1;
    errno = 0;
    DIR *dir = isDirectory ? opendir(fsPath) : NULL;
    int openErr = dir ? 0 : (isDirectory ? errno : 0);
    if (dir) {
        entryCount = 0;
        struct dirent *entry = NULL;
        while ((entry = readdir(dir)) != NULL) {
            if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) entryCount++;
        }
        closedir(dir);
    }
    char resolved[PATH_MAX] = {0};
    errno = 0;
    char *real = realpath(fsPath, resolved);
    int realErr = real ? 0 : errno;
    NSString *realPath = real ? [NSString stringWithUTF8String:resolved] : @"";
    int primaryErr = lstatOK ? (statOK ? 0 : statErr) : lstatErr;
    return @{
        @"path": path,
        @"lstat_exists": @(lstatOK), @"exists": @(statOK),
        @"is_symlink": @(isSymlink), @"is_directory": @(isDirectory),
        @"readable": @(readable), @"enumerable": @(entryCount >= 0),
        @"entry_count": @(entryCount), @"realpath": realPath,
        @"errno": @(primaryErr), @"errno_name": FKErrnoName(primaryErr),
        @"lstat_errno": @(lstatErr), @"stat_errno": @(statErr),
        @"access_errno": @(accessErr), @"opendir_errno": @(openErr), @"realpath_errno": @(realErr),
        @"error": primaryErr ? FKErrnoName(primaryErr) : (entryCount < 0 && isDirectory ? FKErrnoName(openErr) : @"")
    };
}

static id FKSendObject(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSString *FKStringValue(id object, SEL selector) {
    id value = FKSendObject(object, selector);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static NSString *FKSafeString(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

// 主流越狱 prefs/工具优先使用 allInstalledApplications；allApplications 作为旧系统/差异实现兜底。
static NSArray *FKWorkspaceApplicationProxies(id workspace) {
    if (!workspace) return nil;
    id proxies = FKSendObject(workspace, NSSelectorFromString(@"allInstalledApplications"));
    if ([proxies isKindOfClass:NSArray.class]) return proxies;
    proxies = FKSendObject(workspace, NSSelectorFromString(@"allApplications"));
    return [proxies isKindOfClass:NSArray.class] ? proxies : nil;
}

typedef const char *(*FKJBRootFunction)(const char *);
typedef unsigned long long (*FKJBrandFunction)(void);

static FKJBRootFunction FKGetJBRootFunction(void) {
#if FK_HAS_ROOTHIDE_API
    return (FKJBRootFunction)dlsym(RTLD_DEFAULT, "jbroot");
#else
    return NULL;
#endif
}

static FKJBrandFunction FKGetJBrandFunction(void) {
#if FK_HAS_ROOTHIDE_API
    return (FKJBrandFunction)dlsym(RTLD_DEFAULT, "jbrand");
#else
    return NULL;
#endif
}

static NSString *FKResolvedJBPath(NSString *jbRelativePath) {
#if FK_HAS_ROOTHIDE_API
    FKJBRootFunction translate = FKGetJBRootFunction();
    if (!translate) return nil;
    const char *raw = translate(jbRelativePath.fileSystemRepresentation);
    return raw ? [NSString stringWithUTF8String:raw] : nil;
#else
    // Upstream Theos Rootless lane: RootHide header is absent; use the fixed /var/jb prefix.
    NSString *relative = [jbRelativePath hasPrefix:@"/"] ? jbRelativePath : [@"/" stringByAppendingString:jbRelativePath];
    return [@"/var/jb" stringByAppendingString:relative];
#endif
}

static NSString *FKRootFromPath(NSString *path) {
    if (!path.length) return nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"/\\.jbroot-[A-Fa-f0-9]{16}(?=/|$)" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];
    if (!match) return nil;
    return [path substringToIndex:NSMaxRange(match.range)];
}

static NSArray<NSDictionary *> *FKReadDpkgStatus(NSString *statusPath, NSError **outError) {
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:statusPath options:0 error:&readError];
    if (!data) { if (outError) *outError = readError; return @[]; }
    NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!content) content = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!content) { if (outError) *outError = [NSError errorWithDomain:@"FilterKit.DPKG" code:1 userInfo:nil]; return @[]; }
    NSMutableArray *records = [NSMutableArray array];
    NSMutableDictionary *record = nil;
    NSString *currentKey = nil;
    for (NSString *line in [content componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        if (line.length == 0) {
            if (record[@"Package"]) [records addObject:[record copy]];
            record = nil; currentKey = nil; continue;
        }
        if ([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) {
            if (record && currentKey) record[currentKey] = [NSString stringWithFormat:@"%@\n%@", record[currentKey] ?: @"", [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
            continue;
        }
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound || colon.location == 0) continue;
        if (!record) record = [NSMutableDictionary dictionary];
        currentKey = [line substringToIndex:colon.location];
        NSUInteger valueStart = NSMaxRange(colon);
        if (valueStart < line.length && [line characterAtIndex:valueStart] == ' ') valueStart++;
        record[currentKey] = [line substringFromIndex:valueStart];
    }
    if (record[@"Package"]) [records addObject:[record copy]];
    if (outError) *outError = nil;
    return records;
}

static BOOL FKIsSafePackageID(NSString *packageID) {
    if (!packageID.length) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.+-_"];
    return [packageID rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

static NSDictionary *FKImageMagic(NSData *data) {
    const unsigned char *b = data.bytes;
    NSString *format = @"unknown";
    if (data.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) format = @"PNG";
    else if (data.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) format = @"JPEG";
    else if (data.length >= 6 && (!memcmp(b, "GIF87a", 6) || !memcmp(b, "GIF89a", 6))) format = @"GIF";
    else if (data.length >= 12 && !memcmp(b, "RIFF", 4) && !memcmp(b + 8, "WEBP", 4)) format = @"WebP";
    NSMutableString *hex = [NSMutableString string];
    NSUInteger count = MIN((NSUInteger)8, data.length);
    for (NSUInteger i = 0; i < count; i++) [hex appendFormat:@"%02X%@", b[i], i + 1 < count ? @" " : @""];
    return @{@"length": @(data.length), @"magic_hex": hex, @"format": format};
}

static UIImage *FKBundleIcon(NSString *bundlePath, NSString **usedPath) {
    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    NSDictionary *icons = info[@"CFBundleIcons"];
    NSDictionary *primary = icons[@"CFBundlePrimaryIcon"];
    NSArray *names = primary[@"CFBundleIconFiles"];
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSString *name in [names reverseObjectEnumerator]) {
        if (![name isKindOfClass:NSString.class]) continue;
        [candidates addObject:name];
        [candidates addObject:[name stringByAppendingString:@"@3x"]];
        [candidates addObject:[name stringByAppendingString:@"@2x"]];
    }
    id legacy = info[@"CFBundleIconFiles"];
    if ([legacy isKindOfClass:NSArray.class]) [candidates addObjectsFromArray:legacy];
    for (NSString *name in candidates) {
        NSString *file = [bundlePath stringByAppendingPathComponent:name];
        NSArray *paths = file.pathExtension.length ? @[file] : @[[file stringByAppendingPathExtension:@"png"], [file stringByAppendingPathExtension:@"jpg"], file];
        for (NSString *candidate in paths) {
            UIImage *image = [UIImage imageWithContentsOfFile:candidate];
            if (image) { if (usedPath) *usedPath = candidate; return image; }
        }
    }
    return nil;
}


static BOOL FKStatusInstalled(NSString *status) {
    if (![status isKindOfClass:NSString.class]) return NO;
    NSArray *parts = [status componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSString *part in parts) if (part.length) [tokens addObject:part.lowercaseString];
    return tokens.count == 3 && [tokens[0] isEqualToString:@"install"] &&
        [tokens[1] isEqualToString:@"ok"] && [tokens[2] isEqualToString:@"installed"];
}

static NSString *FKInjectorTypeForPackage(NSString *packageID) {
    NSString *name = packageID.lowercaseString ?: @"";
    if ([name containsString:@"ellekit"]) return @"ellekit";
    if ([name containsString:@"substrate"]) return @"substrate";
    if ([name containsString:@"substitute"] || [name containsString:@"libsubstitute"]) return @"substitute";
    if ([name containsString:@"libhooker"] || [name isEqualToString:@"hooker"]) return @"libhooker";
    if ([name containsString:@"libsandy"] || [name containsString:@"sandy"]) return @"sandy";
    return nil;
}

static BOOL FKSuspectInjectorPackage(NSString *packageID) {
    NSString *name = packageID.lowercaseString ?: @"";
    for (NSString *token in @[@"hook", @"substrate", @"ellekit", @"substitute", @"sandy"]) {
        if ([name containsString:token]) return YES;
    }
    return NO;
}

static NSDictionary *FKParseFilterDictionary(id filterObject, NSSet<NSString *> *installedBundleIDs) {
    if (![filterObject isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *filter = (NSDictionary *)filterObject;
    NSArray *knownKeys = @[@"Bundles", @"Executables", @"Classes"];
    NSMutableDictionary *parsed = [NSMutableDictionary dictionary];
    NSMutableArray *warnings = [NSMutableArray array];
    NSMutableArray *otherKeys = [NSMutableArray array];
    NSMutableDictionary *otherValues = [NSMutableDictionary dictionary];
    NSMutableArray *matchedBundleIDs = [NSMutableArray array];
    NSUInteger total = 0; BOOL global = NO;
    for (NSString *key in knownKeys) {
        id value = filter[key];
        if (!value) { parsed[key] = @[]; continue; }
        if (![value isKindOfClass:NSArray.class]) {
            [warnings addObject:[NSString stringWithFormat:@"%@ 不是数组（实际类型 %@）", key, NSStringFromClass([value class])]];
            parsed[key] = @[]; continue;
        }
        NSMutableArray *items = [NSMutableArray array];
        for (id item in (NSArray *)value) {
            if (![item isKindOfClass:NSString.class]) {
                [warnings addObject:[NSString stringWithFormat:@"%@ 含非字符串元素（%@）", key, NSStringFromClass([item class])]];
                continue;
            }
            NSString *normalizedItem = [item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (normalizedItem.length == 0) {
                [warnings addObject:[NSString stringWithFormat:@"%@ 含空字符串，已忽略", key]];
                continue;
            }
            [items addObject:item];
            if ([key isEqualToString:@"Bundles"]) {
                if ([item isEqualToString:@"*"]) global = YES;
                else if ([installedBundleIDs containsObject:item]) [matchedBundleIDs addObject:item];
            }
        }
        parsed[key] = items; total += items.count;
    }
    for (id key in filter.allKeys) {
        if (![key isKindOfClass:NSString.class]) { [warnings addObject:@"Filter 含非字符串键"]; continue; }
        if (![knownKeys containsObject:key]) { [otherKeys addObject:key]; otherValues[key] = filter[key] ?: NSNull.null; }
    }
    parsed[@"other_keys"] = otherKeys;
    parsed[@"other_values"] = otherValues;
    parsed[@"global"] = @(global);
    parsed[@"global_semantics_verified"] = @NO;
    if (global) [warnings addObject:@"Bundles 含 *；按候选全局规则标记，通配语义尚未由 ElleKit loader 源码确认"];
    parsed[@"valid"] = @(total > 0);
    parsed[@"entry_count"] = @(total);
    parsed[@"matched_installed_bundle_ids"] = matchedBundleIDs;
    parsed[@"warnings"] = warnings;
    parsed[@"keys_aligned_with_theos"] = @YES;
    parsed[@"protocol_verified"] = @NO;
    return parsed;
}

static NSString *FKPairKeyForPath(NSString *path) {
    if (![path isKindOfClass:NSString.class] || path.length == 0) return @"";
    NSString *directory = [[path stringByDeletingLastPathComponent] stringByStandardizingPath].lowercaseString;
    NSString *base = [path.lastPathComponent stringByDeletingPathExtension].lowercaseString;
    return [NSString stringWithFormat:@"%@/%@", directory, base];
}

static NSString *FKDescriptionFirstLine(NSString *description) {
    if (![description isKindOfClass:NSString.class] || description.length == 0) return @"";
    NSArray *lines = [description componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length) return trimmed;
    }
    return @"";
}

static NSArray<NSString *> *FKFilterStringArray(NSDictionary *filter, NSString *key) {
    id value = filter[key];
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *result = [NSMutableArray array];
    for (id item in (NSArray *)value) {
        if (![item isKindOfClass:NSString.class]) continue;
        NSString *trimmed = [item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length) [result addObject:trimmed];
    }
    return result;
}

static NSDictionary *FKBuildPluginAssociation(NSArray<NSDictionary *> *apps,
                                               NSArray<NSDictionary *> *dylibs,
                                               NSArray<NSDictionary *> *plists,
                                               NSArray<NSDictionary *> *packages,
                                               NSArray<NSDictionary *> *ownership,
                                               NSString *selectedRoot) {
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *dylibGroups = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *plistGroups = [NSMutableDictionary dictionary];
    for (NSDictionary *item in dylibs) {
        NSString *key = FKPairKeyForPath(FKSafeString(item[@"path"]));
        if (!key.length) continue;
        if (!dylibGroups[key]) dylibGroups[key] = [NSMutableArray array];
        [dylibGroups[key] addObject:item];
    }
    for (NSDictionary *item in plists) {
        NSString *key = FKPairKeyForPath(FKSafeString(item[@"path"]));
        if (!key.length) continue;
        if (!plistGroups[key]) plistGroups[key] = [NSMutableArray array];
        [plistGroups[key] addObject:item];
    }

    NSMutableDictionary<NSString *, NSDictionary *> *packageByID = [NSMutableDictionary dictionary];
    for (NSDictionary *package in packages) {
        NSString *packageID = FKSafeString(package[@"Package"]);
        if (packageID.length) packageByID[packageID] = package;
    }
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *ownersByPath = [NSMutableDictionary dictionary];
    for (NSDictionary *owner in ownership) {
        NSString *packageID = FKSafeString(owner[@"package_id"]);
        for (NSString *path in owner[@"owned_files"] ?: @[]) {
            NSString *normalized = [path stringByStandardizingPath];
            if (!ownersByPath[normalized]) ownersByPath[normalized] = [NSMutableArray array];
            if (![ownersByPath[normalized] containsObject:packageID]) [ownersByPath[normalized] addObject:packageID];
        }
    }
    (void)selectedRoot;

    NSMutableOrderedSet<NSString *> *allKeys = [NSMutableOrderedSet orderedSet];
    [allKeys addObjectsFromArray:dylibGroups.allKeys];
    [allKeys addObjectsFromArray:plistGroups.allKeys];
    NSMutableArray<NSDictionary *> *plugins = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *missingDylib = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *missingPlist = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *unmatchedRules = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *abnormal = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *appPlugins = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *installedIDs = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSString *> *executableToBundle = [NSMutableDictionary dictionary];
    for (NSDictionary *app in apps) {
        NSString *bundleID = FKSafeString(app[@"bundle_id"]);
        if (bundleID.length) [installedIDs addObject:bundleID];
        NSString *exec = FKSafeString(app[@"executable"]).lowercaseString;
        if (exec.length && bundleID.length) executableToBundle[exec] = bundleID;
    }

    for (NSString *key in allKeys) {
        NSArray *dylibMatches = dylibGroups[key] ?: @[];
        NSArray *plistMatches = plistGroups[key] ?: @[];
        NSDictionary *dylib = dylibMatches.firstObject;
        NSDictionary *plist = plistMatches.firstObject;
        NSString *dylibPath = FKSafeString(dylib[@"path"]);
        NSString *plistPath = FKSafeString(plist[@"path"]);
        NSString *baseName = [key.lastPathComponent copy];
        NSMutableArray<NSString *> *ownerIDs = [NSMutableArray array];
        for (NSString *path in @[dylibPath ?: @"", plistPath ?: @""]) {
            if (!path.length) continue;
            NSArray *found = ownersByPath[[path stringByStandardizingPath]] ?: @[];
            for (NSString *packageID in found) if (![ownerIDs containsObject:packageID]) [ownerIDs addObject:packageID];
        }
        NSString *packageID = ownerIDs.count == 1 ? ownerIDs.firstObject : @"";
        NSDictionary *package = packageID.length ? packageByID[packageID] : nil;
        BOOL packageInstalled = package && FKStatusInstalled(FKSafeString(package[@"Status"]));
        NSString *identifier = packageID.length ? packageID : baseName;
        NSString *pluginID = packageID.length ? [NSString stringWithFormat:@"%@:%@", packageID, baseName] : baseName;
        NSString *name = FKDescriptionFirstLine(FKSafeString(package[@"Description"]));
        if (!name.length) name = baseName;
        NSString *version = packageInstalled ? FKSafeString(package[@"Version"]) : @"";
        NSString *fileStatus = (dylib && plist) ? @"complete" : (dylib ? @"missing_plist" : @"missing_dylib");
        NSString *source = packageInstalled ? @"dpkg" : @"manual";

        NSDictionary *filter = [plist[@"filter"] isKindOfClass:NSDictionary.class] ? plist[@"filter"] : @{};
        BOOL parseOK = [plist[@"parse_valid"] boolValue];
        BOOL hasFilter = [plist[@"has_filter_dictionary"] boolValue];
        NSArray *bundleValues = FKFilterStringArray(filter, @"Bundles");
        NSArray *executables = FKFilterStringArray(filter, @"Executables");
        NSArray *classes = FKFilterStringArray(filter, @"Classes");
        BOOL global = [filter[@"global"] boolValue];
        NSMutableArray *matched = [NSMutableArray array];
        NSMutableArray *unmatched = [NSMutableArray array];
        NSMutableArray *matchedExecutables = [NSMutableArray array];
        NSMutableArray *unmatchedExecutables = [NSMutableArray array];
        for (NSString *bundleID in bundleValues) {
            if ([bundleID isEqualToString:@"*"]) continue;
            if ([installedIDs containsObject:bundleID]) [matched addObject:bundleID];
            else [unmatched addObject:bundleID];
        }
        // Executables 规则按进程可执行文件名（CFBundleExecutable）反查已安装 App，与 Bundles 互补。
        for (NSString *exec in executables) {
            NSString *bid = executableToBundle[exec.lowercaseString];
            if (bid) {
                if (![matched containsObject:bid]) [matched addObject:bid];
                [matchedExecutables addObject:exec];
            } else {
                [unmatchedExecutables addObject:exec];
            }
        }
        NSString *configurationStatus = !plist ? @"unknown" : (!parseOK ? @"unparseable" : (!hasFilter ? @"invalid" : (([filter[@"valid"] boolValue] && [filter[@"warnings"] count] == 0) ? @"valid" : @"invalid")));
        NSMutableArray *rules = [NSMutableArray array];
        if (plist) {
            [rules addObject:@{
                @"plugin_id": pluginID,
                @"enabled": @"unknown",
                @"bundle_ids": [bundleValues filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id value, NSDictionary *bindings) { (void)bindings; return [value isKindOfClass:NSString.class] && ![value isEqualToString:@"*"]; }]],
                @"executables": executables,
                @"classes": classes,
                @"exclusions": @[],
                @"global": @(global),
                @"matched_bundle_ids": matched,
                @"unmatched_bundle_ids": unmatched,
                @"matched_executables": matchedExecutables,
                @"unmatched_executables": unmatchedExecutables,
                @"configuration_status": configurationStatus,
                @"warnings": filter[@"warnings"] ?: @[],
                @"other_keys": filter[@"other_keys"] ?: @[],
                @"other_values": filter[@"other_values"] ?: @{},
                @"global_semantics_verified": @NO,
                @"protocol_verified": @NO
            }];
        }
        NSString *associationCategory = @"unresolved_non_bundle_rule";
        if (!plist || !parseOK || !hasFilter) associationCategory = @"unparseable";
        else if ([configurationStatus isEqualToString:@"invalid"]) associationCategory = @"invalid_configuration";
        else if (global) associationCategory = @"global";
        else if (matched.count) associationCategory = @"exact_match";
        else if (unmatched.count || unmatchedExecutables.count) associationCategory = @"unmatched_target";
        NSDictionary *association = @{
            @"category": associationCategory,
            @"global": @(global), @"matched_bundle_ids": matched, @"unmatched_bundle_ids": unmatched,
            @"matched_executables": matchedExecutables, @"unmatched_executables": unmatchedExecutables,
            @"matched_app_count": @(matched.count), @"unmatched_target_count": @(unmatched.count + unmatchedExecutables.count),
            @"note": [associationCategory isEqualToString:@"unresolved_non_bundle_rule"] ? @"规则仅含 Classes 或无可执行名/Bundle 可映射项，当前静态数据不足以映射到具体 App" : @"按静态 Filter 与本机 Bundle ID / CFBundleExecutable 集合分类"
        };
        NSMutableArray *duplicates = [NSMutableArray array];
        if (dylibMatches.count > 1) [duplicates addObject:@"duplicate_dylib_basename"];
        if (plistMatches.count > 1) [duplicates addObject:@"duplicate_plist_basename"];
        if (ownerIDs.count > 1) [duplicates addObject:@"multiple_dpkg_owners"];
        NSDictionary *plugin = @{
            @"PluginID": pluginID, @"Identifier": identifier, @"Name": name, @"Version": version,
            @"DylibPath": dylibPath, @"PlistPath": plistPath,
            @"Source": source, @"PackageID": packageID,
            @"PackageCandidates": ownerIDs, @"FileStatus": fileStatus,
            @"Rules": rules, @"Association": association,
            @"duplicate_flags": duplicates,
            @"pairing": @"same_directory_and_case_insensitive_basename",
            @"package_status": package ? FKSafeString(package[@"Status"]) : @"",
            @"description": FKSafeString(package[@"Description"])
        };
        [plugins addObject:plugin];
        if (dylib && !plist) [missingPlist addObject:@{@"plugin_id": pluginID, @"dylib_path": dylibPath}];
        if (plist && !dylib) [missingDylib addObject:@{@"plugin_id": pluginID, @"plist_path": plistPath}];
        if (unmatched.count) [unmatchedRules addObject:@{@"plugin_id": pluginID, @"bundle_ids": unmatched}];
        if (duplicates.count || [configurationStatus isEqualToString:@"invalid"] || [configurationStatus isEqualToString:@"unparseable"]) {
            [abnormal addObject:@{@"plugin_id": pluginID, @"configuration_status": configurationStatus, @"duplicate_flags": duplicates, @"warnings": filter[@"warnings"] ?: @[]}];
        }
        for (NSString *bundleID in matched) {
            if (!appPlugins[bundleID]) appPlugins[bundleID] = [NSMutableArray array];
            if (![appPlugins[bundleID] containsObject:pluginID]) [appPlugins[bundleID] addObject:pluginID];
        }
    }

    // Build reverse App -> plugin index without changing any original App metadata.
    NSMutableArray *appsWithPlugins = [NSMutableArray arrayWithCapacity:apps.count];
    NSUInteger associatedAppCount = 0;
    for (NSDictionary *app in apps) {
        NSMutableDictionary *updated = [app mutableCopy];
        NSArray *linked = appPlugins[FKSafeString(app[@"bundle_id"])] ?: @[];
        updated[@"plugins"] = linked;
        if (linked.count) associatedAppCount++;
        [appsWithPlugins addObject:updated];
    }

    NSMutableDictionary *identifierGroups = [NSMutableDictionary dictionary];
    NSMutableDictionary *dylibPathGroups = [NSMutableDictionary dictionary];
    NSMutableDictionary *plistPathGroups = [NSMutableDictionary dictionary];
    for (NSDictionary *plugin in plugins) {
        NSString *identifier = FKSafeString(plugin[@"Identifier"]);
        if (!identifierGroups[identifier]) identifierGroups[identifier] = [NSMutableArray array];
        [identifierGroups[identifier] addObject:plugin];
        NSString *dp = FKSafeString(plugin[@"DylibPath"]);
        NSString *pp = FKSafeString(plugin[@"PlistPath"]);
        if (dp.length) { if (!dylibPathGroups[dp]) dylibPathGroups[dp] = [NSMutableArray array]; [dylibPathGroups[dp] addObject:identifier]; }
        if (pp.length) { if (!plistPathGroups[pp]) plistPathGroups[pp] = [NSMutableArray array]; [plistPathGroups[pp] addObject:identifier]; }
    }
    NSMutableArray *duplicateReports = [NSMutableArray array];
    for (NSString *identifier in identifierGroups) if ([identifierGroups[identifier] count] > 1) {
        NSMutableArray *recordIDs = [NSMutableArray array];
        for (NSDictionary *item in identifierGroups[identifier]) [recordIDs addObject:FKSafeString(item[@"PluginID"])];
        [duplicateReports addObject:@{@"type": @"duplicate_identifier", @"value": identifier, @"count": @([identifierGroups[identifier] count]), @"plugin_ids": recordIDs, @"note": @"同一 dpkg 包含多个 dylib/plist 载荷时可能是正常的一包多插件，不直接判定为冲突"}];
    }
    for (NSString *path in dylibPathGroups) if ([dylibPathGroups[path] count] > 1) [duplicateReports addObject:@{@"type": @"duplicate_dylib_path", @"value": path, @"plugin_ids": dylibPathGroups[path]}];
    for (NSString *path in plistPathGroups) if ([plistPathGroups[path] count] > 1) [duplicateReports addObject:@{@"type": @"duplicate_plist_path", @"value": path, @"plugin_ids": plistPathGroups[path]}];

    NSUInteger associatedPlugins = 0, globalPlugins = 0, unmatchedPlugins = 0;
    for (NSDictionary *plugin in plugins) {
        NSDictionary *association = plugin[@"Association"];
        if ([association[@"matched_app_count"] unsignedIntegerValue] > 0) associatedPlugins++;
        if ([association[@"global"] boolValue]) globalPlugins++;
        if ([association[@"unmatched_target_count"] unsignedIntegerValue] > 0) unmatchedPlugins++;
    }
    NSDictionary *summary = @{
        @"scanned_apps": @(apps.count), @"associated_apps": @(associatedAppCount),
        @"discovered_plugins": @(plugins.count), @"associated_plugins": @(associatedPlugins),
        @"global_plugins": @(globalPlugins), @"unmatched_plugins": @(unmatchedPlugins),
        @"abnormal_config": @(abnormal.count), @"duplicate_count": @(duplicateReports.count),
        @"missing_dylib_count": @(missingDylib.count), @"missing_plist_count": @(missingPlist.count),
        @"unmatched_rule_count": @(unmatchedRules.count),
        @"pairing_policy": @"同一目录 + 文件名基名（去扩展名、忽略大小写）；不跨目录猜测配对",
        @"association_policy": @"仅按 Bundles 精确 Bundle ID 关联；Executables/Classes 保留为规则，不冒充 Bundle ID 匹配",
        @"runtime_injection_verified": @NO
    };
    NSDictionary *detail = @{
        @"plugins": plugins, @"apps": appsWithPlugins, @"summary": summary,
        @"duplicates": duplicateReports, @"missing_dylib": missingDylib,
        @"missing_plist": missingPlist, @"unmatched_rules": unmatchedRules,
        @"abnormal": abnormal
    };
    return detail;
}

static NSArray<NSDictionary *> *FKRuntimeInjectorImages(void) {
    NSMutableArray *images = [NSMutableArray array];
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *raw = _dyld_get_image_name(i);
        if (!raw) continue;
        NSString *path = [[NSString stringWithUTF8String:raw] lowercaseString];
        NSString *type = nil;
        if ([path containsString:@"ellekit"]) type = @"ellekit";
        else if ([path containsString:@"substrate"]) type = @"substrate";
        else if ([path containsString:@"substitute"]) type = @"substitute";
        else if ([path containsString:@"libhooker"]) type = @"libhooker";
        else if ([path containsString:@"sandy"]) type = @"sandy";
        if (type) [images addObject:@{@"type": type, @"path": [NSString stringWithUTF8String:raw] ?: @"", @"scope": @"current_process_only"}];
    }
    return images;
}

@interface FKScanner ()
@property (nonatomic, strong) NSMutableArray<FKTestResult *> *results;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *apps;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *jbRoots;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *dynamicPaths;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *dylibs;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *plists;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *dpkgPackages;
@property (nonatomic, strong) NSMutableDictionary *environment;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *iconDiagnostics;
@end

@implementation FKScanner

- (void)add:(NSString *)identifier title:(NSString *)title state:(FKTestState)state detail:(NSString *)detail payload:(NSDictionary *)payload {
    [self.results addObject:[FKTestResult resultWithID:identifier title:title state:state detail:detail payload:payload]];
}

- (void)scanInstalledApps {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = FKSendObject(workspaceClass, NSSelectorFromString(@"defaultWorkspace"));
    id proxies = FKWorkspaceApplicationProxies(workspace);
    if (![proxies isKindOfClass:NSArray.class]) return;
    for (id proxy in proxies) {
        NSString *bundleID = FKStringValue(proxy, NSSelectorFromString(@"applicationIdentifier"));
        if (!bundleID.length) continue;
        NSString *name = FKStringValue(proxy, NSSelectorFromString(@"localizedName")) ?: bundleID;
        NSURL *bundleURL = FKSendObject(proxy, NSSelectorFromString(@"bundleURL"));
        NSString *bundlePath = bundleURL.path ?: @"";
        NSDictionary *bundleInfo = bundlePath.length ? [NSDictionary dictionaryWithContentsOfFile:[bundlePath stringByAppendingPathComponent:@"Info.plist"]] : nil;
        NSString *shortVersion = FKSafeString(bundleInfo[@"CFBundleShortVersionString"]);
        NSString *buildVersion = FKSafeString(bundleInfo[@"CFBundleVersion"]);
        NSString *versionSource = shortVersion.length ? @"Info.plist:CFBundleShortVersionString" : (buildVersion.length ? @"Info.plist:CFBundleVersion" : @"unknown");
        NSString *version = shortVersion.length ? shortVersion : buildVersion;
        NSString *executableName = FKSafeString(bundleInfo[@"CFBundleExecutable"]);
        NSString *iconPath = nil;
        UIImage *bundleIcon = FKBundleIcon(bundlePath, &iconPath);
        NSMutableDictionary *app = [@{
            @"bundle_id": bundleID, @"name": name, @"version": version ?: @"",
            @"version_source": versionSource, @"build_version": buildVersion ?: @"",
            @"bundle_path": bundlePath, @"executable": executableName,
            @"is_system": @([bundlePath hasPrefix:@"/Applications/"] || [bundlePath hasPrefix:@"/System/"])
        } mutableCopy];
        if (bundleIcon) {
            app[@"icon_source"] = @"bundle_file";
            app[@"icon_path"] = iconPath ?: @"";
        } else {
            app[@"icon_source"] = @"unresolved";
        }
        [self.apps addObject:app];
    }
}

- (void)scanIconFallbacks {
    NSUInteger selectorCount = 0, dataCount = 0, decodeCount = 0, magicImageCount = 0;
    // Re-query proxies for a guarded, signature-checked private API fallback.
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = FKSendObject(workspaceClass, NSSelectorFromString(@"defaultWorkspace"));
    id proxies = FKWorkspaceApplicationProxies(workspace);
    if (![proxies isKindOfClass:NSArray.class]) return;
    for (id proxy in proxies) {
        NSString *bundleID = FKStringValue(proxy, NSSelectorFromString(@"applicationIdentifier"));
        if (!bundleID.length) continue;
        NSUInteger appIndex = [self.apps indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop; return [obj[@"bundle_id"] isEqualToString:bundleID];
        }];
        if (appIndex == NSNotFound || [self.apps[appIndex][@"icon_source"] isEqualToString:@"bundle_file"]) continue;
        SEL selector = NSSelectorFromString(@"iconDataForVariant:withOptions:");
        if (![proxy respondsToSelector:selector]) continue;
        selectorCount++;
        NSMethodSignature *signature = [proxy methodSignatureForSelector:selector];
        if (!signature || signature.numberOfArguments != 4 || strcmp(signature.methodReturnType, @encode(id)) != 0) continue;
        const char *variantType = [signature getArgumentTypeAtIndex:2];
        if (!(variantType[0] == 'Q' || variantType[0] == 'q' || variantType[0] == 'I' || variantType[0] == 'i' || variantType[0] == 'L' || variantType[0] == 'l')) continue;
        const char *optionsType = [signature getArgumentTypeAtIndex:3];
        if (optionsType[0] != '@') continue;
        for (NSUInteger variant = 0; variant < 4; variant++) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.target = proxy; invocation.selector = selector;
            NSUInteger rawVariant = variant;
            __unsafe_unretained id options = @{};
            [invocation setArgument:&rawVariant atIndex:2];
            [invocation setArgument:&options atIndex:3];
            [invocation invoke];
            __unsafe_unretained id returned = nil;
            [invocation getReturnValue:&returned];
            if (![returned isKindOfClass:NSData.class]) continue;
            NSData *data = [returned copy]; dataCount++;
            NSDictionary *magic = FKImageMagic(data);
            BOOL knownImage = ![magic[@"format"] isEqualToString:@"unknown"];
            if (knownImage) magicImageCount++;
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                decodeCount++;
                NSMutableDictionary *updated = [self.apps[appIndex] mutableCopy];
                updated[@"icon_source"] = @"private_api";
                updated[@"icon_variant"] = @(variant);
                self.apps[appIndex] = updated;
                break;
            }
            if (self.iconDiagnostics.count < 40) {
                [self.iconDiagnostics addObject:@{@"bundle_id": bundleID, @"variant": @(variant), @"data_length": magic[@"length"],
                    @"magic_hex": magic[@"magic_hex"], @"format": magic[@"format"], @"uiimage_decoded": @NO, @"decode_error": @"UIImage imageWithData 返回 nil"}];
            }
        }
    }
    NSUInteger localIconCount = 0;
    for (NSDictionary *app in self.apps) if (![app[@"icon_source"] isEqualToString:@"unresolved"]) localIconCount++;
    self.environment[@"app_icon_diagnostics"] = @{
        @"bundle_icon_count": @(localIconCount), @"private_api_selector_count": @(selectorCount),
        @"private_api_data_count": @(dataCount), @"recognized_image_magic_count": @(magicImageCount),
        @"private_api_decode_count": @(decodeCount), @"samples": self.iconDiagnostics.copy,
        @"cloud_lookup": @"not_requested_in_read_only_poc"
    };
}

- (FKScanReport *)runScan {
    self.results = [NSMutableArray array]; self.apps = [NSMutableArray array]; self.jbRoots = [NSMutableArray array];
    self.dynamicPaths = [NSMutableArray array]; self.dylibs = [NSMutableArray array]; self.plists = [NSMutableArray array];
    self.dpkgPackages = [NSMutableArray array]; self.environment = [NSMutableDictionary dictionary]; self.iconDiagnostics = [NSMutableArray array];

    struct utsname machineInfo; NSString *machineArch = @"unknown";
    if (uname(&machineInfo) == 0) machineArch = [NSString stringWithUTF8String:machineInfo.machine] ?: @"unknown";
    self.environment[@"ios_version"] = UIDevice.currentDevice.systemVersion ?: @"unknown";
    self.environment[@"architecture"] = machineArch;
    self.environment[@"jailbreak"] = @"unknown";
    self.environment[@"roothide_api_available_at_build"] = @(FK_HAS_ROOTHIDE_API);
    self.environment[@"ellekit"] = @{@"version": NSNull.null, @"package_id": @"", @"package_status": @"", @"version_source": @"", @"detection_status": @"unknown"};

    // App enumeration is performed first because its own bundle path is a JBROOT discovery signal.
    [self scanInstalledApps];
    NSString *selfBundlePath = NSBundle.mainBundle.bundlePath ?: @"";
    NSMutableOrderedSet<NSString *> *rootCandidates = [NSMutableOrderedSet orderedSet];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *rootSources = [NSMutableDictionary dictionary];
    void (^addRoot)(NSString *, NSString *) = ^(NSString *root, NSString *source) {
        if (!root.length) return;
        [rootCandidates addObject:root];
        if (!rootSources[root]) rootSources[root] = [NSMutableArray array];
        if (![rootSources[root] containsObject:source]) [rootSources[root] addObject:source];
    };
#if FK_HAS_ROOTHIDE_API
    FKJBRootFunction jbrootFunction = FKGetJBRootFunction();
    FKJBrandFunction jbrandFunction = FKGetJBrandFunction();
    self.environment[@"roothide_api_available_at_runtime"] = @(jbrootFunction != NULL && jbrandFunction != NULL);
    if (jbrootFunction && jbrandFunction) {
        const char *rawRoot = jbrootFunction("/");
        NSString *apiRoot = rawRoot ? [NSString stringWithUTF8String:rawRoot] : nil;
        if (apiRoot.length) {
            while (apiRoot.length > 1 && [apiRoot hasSuffix:@"/"]) apiRoot = [apiRoot substringToIndex:apiRoot.length - 1];
            addRoot(apiRoot, @"libroothide:jbroot(/)");
        } else {
            self.environment[@"roothide_api_error"] = @"jbroot(/) returned an empty path";
        }
        unsigned long long brand = jbrandFunction();
        self.environment[@"jbrand_hex"] = [NSString stringWithFormat:@"%016llX", brand];
        self.environment[@"jbrand_available"] = @(brand != 0);
    } else {
        self.environment[@"roothide_api_error"] = @"libroothide symbols are not loaded in this process; fallback discovery will be used";
        self.environment[@"jbrand_hex"] = NSNull.null;
        self.environment[@"jbrand_available"] = @NO;
    }
#else
    self.environment[@"roothide_api_available_at_runtime"] = @NO;
    self.environment[@"jbrand_hex"] = NSNull.null;
    self.environment[@"jbrand_available"] = @NO;
#endif
    NSString *selfRoot = FKRootFromPath(selfBundlePath);
    if (selfRoot) addRoot(selfRoot, @"main_bundle_path");
    for (NSDictionary *app in self.apps) {
        NSString *candidate = FKRootFromPath(FKSafeString(app[@"bundle_path"]));
        if (candidate) addRoot(candidate, @"installed_app_bundle_path");
    }
    NSString *containerPath = @"/private/var/containers/Bundle/Application";
    NSDictionary *containerProbe = FKPathProbe(containerPath);
    NSMutableArray *containerEntries = [NSMutableArray array];
    if ([containerProbe[@"enumerable"] boolValue]) {
        DIR *dir = opendir(containerPath.fileSystemRepresentation);
        if (dir) {
            struct dirent *entry = NULL;
            while ((entry = readdir(dir)) != NULL) {
                NSString *name = [NSString stringWithUTF8String:entry->d_name];
                if ([name hasPrefix:@".jbroot-"]) {
                    NSString *root = [containerPath stringByAppendingPathComponent:name];
                    [containerEntries addObject:root]; addRoot(root, @"container_directory_scan");
                }
            }
            closedir(dir);
        }
    }
    NSArray *fixedRoots = @[@"/var/jb", @"/var/rootless", @"/private/var/jb"];
    for (NSString *fixed in fixedRoots) addRoot(fixed, @"fixed_rootless_fallback");

    NSMutableArray *rootProbeResults = [NSMutableArray array];
    NSMutableArray<NSString *> *validRoots = [NSMutableArray array];
    for (NSString *root in rootCandidates) {
        NSDictionary *probe = FKPathProbe(root);
        NSMutableArray *markers = [NSMutableArray array];
        NSArray *markerSuffixes = @[@"Applications", @"Library", @"var/lib/dpkg/status", @"Library/MobileSubstrate/DynamicLibraries", @"Library/ElleKit/DynamicLibraries"];
        for (NSString *suffix in markerSuffixes) {
            NSString *marker = [root stringByAppendingPathComponent:suffix];
            NSDictionary *markerProbe = FKPathProbe(marker);
            if ([markerProbe[@"exists"] boolValue]) [markers addObject:@{@"path": marker, @"is_directory": markerProbe[@"is_directory"], @"readable": markerProbe[@"readable"]}];
        }
        BOOL rootOK = [probe[@"exists"] boolValue] && [probe[@"is_directory"] boolValue];
        BOOL structuralEvidence = NO;
        for (NSDictionary *marker in markers) if ([marker[@"path"] hasSuffix:@"/Applications"] || [marker[@"path"] hasSuffix:@"/Library"]) structuralEvidence = YES;
        BOOL confirmed = rootOK && (structuralEvidence || [root hasSuffix:@"/jb"] || [root hasSuffix:@"/rootless"]);
        if (confirmed) [validRoots addObject:root];
        [rootProbeResults addObject:@{@"root": root, @"sources": rootSources[root] ?: @[], @"probe": probe,
            @"markers": markers, @"confirmed": @(confirmed), @"confidence": confirmed ? @"confirmed" : (rootOK ? @"candidate" : @"path_hint_only")}];
    }
    NSString *selectedRoot = nil;
    for (NSDictionary *item in rootProbeResults) {
        if ([item[@"confirmed"] boolValue] && [item[@"sources"] containsObject:@"libroothide:jbroot(/)"]) { selectedRoot = item[@"root"]; break; }
    }
    if (!selectedRoot) selectedRoot = validRoots.firstObject;
    for (NSDictionary *item in rootProbeResults) [self.jbRoots addObject:item];
    self.environment[@"jbroot"] = selectedRoot ?: NSNull.null;
    self.environment[@"jbroot_sources"] = selectedRoot ? (rootSources[selectedRoot] ?: @[]) : @[];
    self.environment[@"jailbreak"] = selectedRoot ? ([rootSources[selectedRoot] containsObject:@"libroothide:jbroot(/)"] ? @"RootHide" : @"Rootless/RootHide candidate") : @"unknown";
    [self add:@"jbroot" title:@"JBROOT 路径定位与校验" state:selectedRoot ? FKTestStatePassed : (rootCandidates.count ? FKTestStateUnknown : FKTestStateFailed)
        detail:[NSString stringWithFormat:@"候选 %lu 个；确认 %lu 个；%@", (unsigned long)rootCandidates.count, (unsigned long)validRoots.count, selectedRoot ?: @"未确认有效根目录"]
        payload:@{@"selected_root": selectedRoot ?: @"", @"candidates": rootProbeResults, @"container_probe": containerProbe,
            @"container_jbroot_entries": containerEntries, @"self_bundle_path": selfBundlePath,
            @"discovery_order": @[@"libroothide", @"main_bundle_path", @"installed_app_bundle_path", @"container_directory_scan", @"fixed_rootless_fallback"]}];

    // All jailbroken paths are constructed from the detected root. The API path is a preferred independent candidate.
    NSMutableOrderedSet<NSString *> *dynamicCandidates = [NSMutableOrderedSet orderedSet];
    NSArray *dynamicSuffixes = @[@"Library/ElleKit/DynamicLibraries", @"Library/MobileSubstrate/DynamicLibraries", @"library/MobileSubstrate/DynamicLibraries"];
    if (selectedRoot) for (NSString *suffix in dynamicSuffixes) [dynamicCandidates addObject:[selectedRoot stringByAppendingPathComponent:suffix]];
    if (FK_HAS_ROOTHIDE_API) {
        for (NSString *suffix in dynamicSuffixes) {
            NSString *translated = FKResolvedJBPath([@"/" stringByAppendingString:suffix]);
            if (translated.length) [dynamicCandidates addObject:translated];
        }
    }
    for (NSString *fixed in fixedRoots) for (NSString *suffix in dynamicSuffixes) [dynamicCandidates addObject:[[fixed stringByAppendingPathComponent:suffix] stringByStandardizingPath]];
    NSMutableArray *dynamicReadable = [NSMutableArray array];
    for (NSString *path in dynamicCandidates) {
        NSDictionary *probe = FKPathProbe(path); [self.dynamicPaths addObject:probe];
        if ([probe[@"is_directory"] boolValue] && [probe[@"readable"] boolValue] && [probe[@"enumerable"] boolValue]) [dynamicReadable addObject:path];
    }
    [self add:@"dynamic_paths" title:@"DynamicLibraries 目录访问" state:dynamicReadable.count ? FKTestStatePassed : (selectedRoot ? FKTestStateFailed : FKTestStateUnknown)
        detail:[NSString stringWithFormat:@"探测 %lu 个目录；可读取并枚举 %lu 个", (unsigned long)dynamicCandidates.count, (unsigned long)dynamicReadable.count]
        payload:@{@"readable_directories": dynamicReadable, @"candidates": self.dynamicPaths}];

    // dylib enumeration: success is directory enumeration, even if there are zero dylib files.
    NSMutableOrderedSet<NSString *> *seenDylibs = [NSMutableOrderedSet orderedSet];
    BOOL dylibEnumerationCompleted = dynamicReadable.count > 0;
    for (NSString *dir in dynamicReadable) {
        DIR *dp = opendir(dir.fileSystemRepresentation); if (!dp) continue;
        struct dirent *entry = NULL;
        while ((entry = readdir(dp)) != NULL) {
            NSString *name = [NSString stringWithUTF8String:entry->d_name];
            if ([name.pathExtension.lowercaseString isEqualToString:@"dylib"]) {
                NSString *path = [dir stringByAppendingPathComponent:name];
                if (![seenDylibs containsObject:path]) { [seenDylibs addObject:path]; [self.dylibs addObject:@{@"name": name, @"path": path}]; }
            }
        }
        closedir(dp);
    }
    [self add:@"dylib_scan" title:@"dylib 文件枚举" state:dylibEnumerationCompleted ? FKTestStatePassed : FKTestStateUnknown
        detail:[NSString stringWithFormat:@"%@；发现 %lu 个 dylib", dylibEnumerationCompleted ? @"目录枚举成功" : @"没有可枚举目录", (unsigned long)self.dylibs.count]
        payload:@{@"enumeration_completed": @(dylibEnumerationCompleted), @"count": @(self.dylibs.count), @"files": self.dylibs}];

    NSUInteger readablePlists = 0, parsedPlists = 0, filterDictionaries = 0, validFilters = 0;
    NSMutableSet<NSString *> *installedBundleIDs = [NSMutableSet set];
    for (NSDictionary *app in self.apps) if ([app[@"bundle_id"] isKindOfClass:NSString.class]) [installedBundleIDs addObject:app[@"bundle_id"]];
    for (NSString *dir in dynamicReadable) {
        NSArray *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil] ?: @[];
        for (NSString *name in names) {
            if (![name.pathExtension.lowercaseString isEqualToString:@"plist"]) continue;
            NSString *path = [dir stringByAppendingPathComponent:name]; NSError *readError = nil;
            NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&readError];
            if (!data) { [self.plists addObject:@{@"name": name, @"path": path, @"readable": @NO, @"read_error": readError.localizedDescription ?: @"读取失败"}]; continue; }
            readablePlists++; NSError *parseError = nil;
            id object = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&parseError];
            BOOL parsedOK = object != nil; if (parsedOK) parsedPlists++;
            NSDictionary *top = [object isKindOfClass:NSDictionary.class] ? object : nil;
            id filterObject = top[@"Filter"];
            NSDictionary *filterResult = FKParseFilterDictionary(filterObject, installedBundleIDs);
            if ([filterObject isKindOfClass:NSDictionary.class]) filterDictionaries++;
            if ([filterResult[@"valid"] boolValue]) validFilters++;
            NSMutableDictionary *plistRecord = [@{@"name": name, @"path": path, @"readable": @YES, @"data_length": @(data.length),
                @"parse_valid": @(parsedOK), @"top_level_type": object ? NSStringFromClass([object class]) : @"invalid",
                @"top_level_keys": top.allKeys ?: @[], @"has_filter_dictionary": @(filterResult != nil),
                @"filter": filterResult ?: @{}, @"filter_protocol_verified": @NO,
                @"parse_error": parseError.localizedDescription ?: @""} mutableCopy];
            [self.plists addObject:plistRecord];
        }
    }
    [self add:@"plist_read" title:@"plist 文件读取" state:readablePlists ? FKTestStatePassed : FKTestStateUnknown
        detail:[NSString stringWithFormat:@"读取 %lu 个 plist；成功解析 %lu 个", (unsigned long)readablePlists, (unsigned long)parsedPlists]
        payload:@{@"readable_count": @(readablePlists), @"parsed_count": @(parsedPlists), @"files": self.plists}];
    [self add:@"filter_parse" title:@"Filter 配置解析" state:filterDictionaries ? FKTestStatePassed : FKTestStateUnknown
        detail:[NSString stringWithFormat:@"发现 %lu 个 Filter 字典；其中 %lu 个含有效匹配项；协议语义仍待 loader 源码验证", (unsigned long)filterDictionaries, (unsigned long)validFilters]
        payload:@{@"filter_dictionary_count": @(filterDictionaries), @"valid_filter_count": @(validFilters),
            @"candidate_fields": @[@"Bundles", @"Executables", @"Classes"], @"keys_aligned_with_theos": @YES,
            @"protocol_verified": @NO, @"note": @"按 Theos 文档键名解析；不宣称 ElleKit loader 接受语义已验证"}];

    NSMutableOrderedSet<NSString *> *statusCandidates = [NSMutableOrderedSet orderedSet];
    if (selectedRoot) [statusCandidates addObject:[selectedRoot stringByAppendingPathComponent:@"var/lib/dpkg/status"]];
    if (FK_HAS_ROOTHIDE_API) {
        NSString *translatedStatus = FKResolvedJBPath(@"/var/lib/dpkg/status");
        if (translatedStatus.length) [statusCandidates addObject:translatedStatus];
    }
    for (NSString *root in validRoots) [statusCandidates addObject:[root stringByAppendingPathComponent:@"var/lib/dpkg/status"]];
    for (NSString *root in fixedRoots) [statusCandidates addObject:[root stringByAppendingPathComponent:@"var/lib/dpkg/status"]];
    NSMutableArray *statusProbes = [NSMutableArray array]; NSString *statusPath = nil;
    for (NSString *candidate in statusCandidates) {
        NSDictionary *probe = FKPathProbe(candidate); [statusProbes addObject:probe];
        if (!statusPath && [probe[@"exists"] boolValue] && [probe[@"readable"] boolValue]) statusPath = candidate;
    }
    NSError *statusError = nil; NSArray *packages = statusPath ? FKReadDpkgStatus(statusPath, &statusError) : @[];
    [self.dpkgPackages addObjectsFromArray:packages];
    BOOL statusParsed = statusPath && !statusError && packages.count > 0;
    [self add:@"dpkg_status" title:@"dpkg status 读取与解析" state:statusParsed ? FKTestStatePassed : (statusPath ? FKTestStateUnknown : FKTestStateUnknown)
        detail:statusParsed ? [NSString stringWithFormat:@"成功解析 %lu 个包记录", (unsigned long)packages.count] : (statusPath ? @"文件可读，但未解析出有效包记录" : @"未找到可读取的 status 文件")
        payload:@{@"path": statusPath ?: @"", @"read_succeeded": @(statusPath != nil && statusError == nil), @"parse_succeeded": @(statusParsed),
            @"package_count": @(packages.count), @"read_error": statusError.localizedDescription ?: @"", @"candidates": statusProbes}];

    NSMutableArray *ownership = [NSMutableArray array]; NSUInteger ownershipCount = 0;
    NSString *infoDir = statusPath ? [[statusPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"info"] : (selectedRoot ? [selectedRoot stringByAppendingPathComponent:@"var/lib/dpkg/info"] : nil);
    for (NSDictionary *package in packages) {
        NSString *packageID = package[@"Package"];
        if (!FKIsSafePackageID(packageID) || !infoDir) continue;
        NSString *listPath = [infoDir stringByAppendingPathComponent:[packageID stringByAppendingString:@".list"]];
        NSData *listData = [NSData dataWithContentsOfFile:listPath];
        if (!listData) continue;
        ownershipCount++;
        NSString *listText = [[NSString alloc] initWithData:listData encoding:NSUTF8StringEncoding] ?: @"";
        NSMutableSet<NSString *> *listedPaths = [NSMutableSet set];
        for (NSString *line in [listText componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (trimmed.length) [listedPaths addObject:[trimmed stringByStandardizingPath]];
        }
        BOOL (^isOwned)(NSString *) = ^BOOL(NSString *absolutePath) {
            if (!absolutePath.length) return NO;
            NSString *normalized = [absolutePath stringByStandardizingPath];
            if ([listedPaths containsObject:normalized]) return YES;
            if (selectedRoot.length && [normalized hasPrefix:selectedRoot]) {
                NSString *relative = [normalized substringFromIndex:selectedRoot.length];
                NSString *relativeNormalized = [relative stringByStandardizingPath];
                if (relative.length && [listedPaths containsObject:relativeNormalized]) return YES;
                if (relative.length && [listedPaths containsObject:[[ @"/var/jb" stringByAppendingString:relativeNormalized] stringByStandardizingPath]]) return YES;
            }
            return NO;
        };
        NSMutableArray *ownedDylibs = [NSMutableArray array];
        NSMutableArray *ownedFiles = [NSMutableArray array];
        for (NSDictionary *dylib in self.dylibs) {
            NSString *dylibPath = dylib[@"path"];
            if (isOwned(dylibPath)) { [ownedDylibs addObject:dylibPath]; [ownedFiles addObject:dylibPath]; }
        }
        for (NSDictionary *plist in self.plists) {
            NSString *plistPath = plist[@"path"];
            if (isOwned(plistPath)) [ownedFiles addObject:plistPath];
        }
        [ownership addObject:@{@"package_id": packageID, @"list_path": listPath, @"list_length": @(listData.length), @"owned_dylibs": ownedDylibs, @"owned_files": ownedFiles}];
    }
    [self add:@"dpkg_ownership" title:@"dpkg 包文件归属分析" state:ownershipCount ? FKTestStatePassed : FKTestStateUnknown
        detail:[NSString stringWithFormat:@"读取 %lu 个包文件清单", (unsigned long)ownershipCount]
        payload:@{@"readable_list_files": @(ownershipCount), @"packages": ownership, @"info_directory": infoDir ?: @"",
            @"note": @"以 info/<package>.list 为文件归属证据；Conffiles 不作为完整文件清单"}];

    NSDictionary *dpkgAnalysis = [FKDPKGAnalyzer analyzeStatusAtPath:statusPath selectedRoot:selectedRoot ?: @"" packages:packages dylibs:self.dylibs plists:self.plists];
    NSDictionary *dpkgSummary = dpkgAnalysis[@"summary"] ?: @{};
    [self add:@"dpkg_metadata" title:@"dpkg 包元数据深度解析" state:(statusParsed ? FKTestStatePassed : FKTestStateUnknown)
        detail:[NSString stringWithFormat:@"解析 %lu 个包记录；保留控制字段与多行描述", (unsigned long)packages.count]
        payload:@{@"package_count":@(packages.count), @"fields":@[@"Package",@"Version",@"Architecture",@"Status",@"Maintainer",@"Description",@"Depends",@"Pre-Depends",@"Recommends",@"Suggests",@"Provides",@"Conflicts",@"Replaces",@"Source",@"Section",@"Essential",@"Homepage"], @"summary":dpkgSummary}];
    [self add:@"dpkg_state" title:@"dpkg 安装状态拆解" state:(statusParsed ? FKTestStatePassed : FKTestStateUnknown)
        detail:[NSString stringWithFormat:@"已安装 %lu；未配置 %lu；异常 %lu", (unsigned long)[dpkgSummary[@"installed_packages"] unsignedIntegerValue], (unsigned long)[dpkgSummary[@"unpacked_packages"] unsignedIntegerValue], (unsigned long)[dpkgSummary[@"broken_packages"] unsignedIntegerValue]]
        payload:@{@"installed":dpkgSummary[@"installed_packages"] ?: @0, @"unpacked":dpkgSummary[@"unpacked_packages"] ?: @0, @"broken":dpkgSummary[@"broken_packages"] ?: @0}];
    [self add:@"dpkg_file_integrity" title:@"dpkg 文件清单与实际文件核对" state:(statusParsed ? FKTestStatePassed : FKTestStateUnknown)
        detail:[NSString stringWithFormat:@"缺失文件 %lu；未归属插件文件 %lu", (unsigned long)[dpkgSummary[@"missing_package_files"] unsignedIntegerValue], (unsigned long)[dpkgSummary[@"unowned_plugin_files"] unsignedIntegerValue]]
        payload:dpkgSummary];
    NSDictionary *integrity = dpkgAnalysis[@"integrity"] ?: @{};
    NSArray *checksumMismatches = integrity[@"checksum_mismatches"] ?: @[];
    NSUInteger checksumChecked = 0;
    for (NSDictionary *pkgResult in dpkgAnalysis[@"packages"] ?: @[]) checksumChecked += [pkgResult[@"checksum_checked"] unsignedIntegerValue];
    NSDictionary *checksumAnalysis = [integrity[@"checksum_analysis"] isKindOfClass:NSDictionary.class] ? integrity[@"checksum_analysis"] : @{};
    NSUInteger checksumHardFailures = [checksumAnalysis[@"hard_failures"] unsignedIntegerValue];
    NSUInteger checksumWarnings = [checksumAnalysis[@"warnings"] unsignedIntegerValue];
    NSUInteger checksumNotConfirmed = [checksumAnalysis[@"not_confirmed"] unsignedIntegerValue];
    FKTestState checksumState = checksumChecked == 0 ? FKTestStateUnknown : (checksumHardFailures ? FKTestStateFailed : (checksumNotConfirmed ? FKTestStateUnknown : FKTestStatePassed));
    NSString *checksumDetail = checksumChecked == 0 ? @"没有可验证的 MD5 记录；不将缺少校验记录视为失败" : [NSString stringWithFormat:@"已校验 %lu 项；原始不匹配 %lu；硬失败 %lu；预期差异/警告 %lu；未确认 %lu", (unsigned long)checksumChecked, (unsigned long)checksumMismatches.count, (unsigned long)checksumHardFailures, (unsigned long)checksumWarnings, (unsigned long)checksumNotConfirmed];
    [self add:@"dpkg_checksum" title:@"dpkg MD5 清单校验" state:checksumState detail:checksumDetail
        payload:@{@"checked":@(checksumChecked), @"mismatches":checksumMismatches, @"checksum_analysis":checksumAnalysis, @"integrity":integrity, @"note":@"保留原始 MD5 差异；Mach-O 不匹配单列警告；非 Conffiles plist 差异列为 configuration_review/未确认，不仅凭 MD5 推断恶意篡改"}];
    NSDictionary *associationResult = FKBuildPluginAssociation(self.apps, self.dylibs, self.plists, packages, ownership, selectedRoot ?: @"");
    self.apps = [associationResult[@"apps"] mutableCopy] ?: self.apps;
    NSDictionary *associationSummary = associationResult[@"summary"] ?: @{};
    NSMutableDictionary *dpkgPackageByID = [NSMutableDictionary dictionary];
    for (NSDictionary *pkg in dpkgAnalysis[@"packages"] ?: @[]) if ([pkg[@"package_id"] isKindOfClass:NSString.class]) dpkgPackageByID[pkg[@"package_id"]] = pkg;
    NSMutableArray *pluginsWithSource = [NSMutableArray array];
    for (NSDictionary *plugin in associationResult[@"plugins"] ?: @[]) {
        NSMutableDictionary *item = [plugin mutableCopy];
        NSString *pid = FKSafeString(plugin[@"PackageID"]);
        NSDictionary *meta = pid.length ? dpkgPackageByID[pid] : nil;
        item[@"PackageMetadata"] = meta ?: @{@"source_status":@"unknown", @"evidence":@"no_exact_dpkg_owner"};
        item[@"OwnershipEvidence"] = @{@"package_candidates":plugin[@"PackageCandidates"] ?: @[],
            @"source":plugin[@"Source"] ?: @"unknown", @"exact_package_record":@(meta != nil),
            @"note":@"来源仅在 .list 路径与插件文件精确对应且包记录存在时确认；不按文件名猜测"};
        [pluginsWithSource addObject:item];
    }
    [self add:@"plugin_source" title:@"插件来源与包元数据追踪" state:pluginsWithSource.count ? FKTestStatePassed : FKTestStateUnknown
        detail:[NSString stringWithFormat:@"为 %lu 个插件附加 dpkg 来源证据", (unsigned long)pluginsWithSource.count]
        payload:@{@"plugin_count":@(pluginsWithSource.count), @"plugins":pluginsWithSource}];
    NSArray *fileOwners = dpkgAnalysis[@"file_ownership"] ?: @[];
    NSMutableArray *ownershipConflicts = [NSMutableArray array];
    for (NSDictionary *owner in fileOwners) if ([owner[@"conflict"] boolValue]) [ownershipConflicts addObject:owner];
    [self add:@"ownership_conflict" title:@"文件多包归属冲突检测" state:(statusParsed ? FKTestStatePassed : FKTestStateUnknown)
        detail:[NSString stringWithFormat:@"发现 %lu 个多归属路径", (unsigned long)ownershipConflicts.count]
        payload:@{@"conflicts":ownershipConflicts, @"count":@(ownershipConflicts.count)}];
    // 0.0.9 诊断修复：RootHelper 双向关联只读预检。永不启动、安装、发信号或与 helper 通信，不调用 launchctl。
    NSMutableArray *helperCandidates = [NSMutableArray array];
    NSMutableArray *helperRegistrations = [NSMutableArray array];

    // 路径 -> dpkg 归属包集合（逻辑路径），用于把候选/程序关联到具体软件包。
    NSMutableDictionary<NSString *, NSArray *> *helperOwners = [NSMutableDictionary dictionary];
    for (NSDictionary *owner in dpkgAnalysis[@"file_ownership"] ?: @[]) {
        NSString *op = owner[@"path"];
        if ([op isKindOfClass:NSString.class]) helperOwners[op] = owner[@"packages"] ?: @[];
    }
    NSString *(^FKHelperLogicalPath)(NSString *) = ^NSString *(NSString *physical) {
        if (![physical isKindOfClass:NSString.class] || physical.length == 0) return @"";
        NSString *p = [physical stringByStandardizingPath];
        if (selectedRoot.length && [p hasPrefix:selectedRoot]) p = [p substringFromIndex:selectedRoot.length];
        if (![p hasPrefix:@"/"]) p = [@"/" stringByAppendingString:p];
        return [p stringByStandardizingPath];
    };
    NSDictionary *(^FKHelperProbe)(NSString *) = ^NSDictionary *(NSString *path) {
        // 使用 lstat 观察候选本身，避免把指向其他文件的符号链接误判为普通可执行文件。
        struct stat st = {0};
        BOOL exists = lstat(path.fileSystemRepresentation, &st) == 0;
        BOOL regular = exists && S_ISREG(st.st_mode);
        BOOL executable = regular && access(path.fileSystemRepresentation, X_OK) == 0;
        NSString *fileType = !exists ? @"unknown" : (S_ISREG(st.st_mode) ? @"regular" :
            (S_ISLNK(st.st_mode) ? @"symlink" : (S_ISDIR(st.st_mode) ? @"directory" : @"other")));
        NSString *logical = FKHelperLogicalPath(path);
        return @{@"path":path,@"exists":@(exists),@"regular_file":@(regular),@"executable":@(executable),
                 @"file_type":fileType,@"size":@(exists ? st.st_size : 0),@"logical_path":logical,
                 @"package_ids":helperOwners[logical] ?: @[]};
    };
    NSMutableSet *seenHelperPaths = [NSMutableSet set];

    // A. 正向发现：先保留固定候选路径作为存在性证据，再在受限可执行目录按文件名关键词枚举，不扫描全盘。
    NSArray *helperFixedRelative = @[@"usr/libexec/RootHelper", @"usr/libexec/roothelper", @"usr/libexec/roothide/RootHelper", @"usr/libexec/roothide/roothelper", @"usr/bin/RootHelper"];
    for (NSString *relative in helperFixedRelative) {
        NSMutableArray *paths = [NSMutableArray array];
        if (selectedRoot.length) [paths addObject:[selectedRoot stringByAppendingPathComponent:relative]];
        [paths addObject:[@"/var/jb" stringByAppendingPathComponent:relative]];
        [paths addObject:[@"/" stringByAppendingPathComponent:relative]];
        for (NSString *candidate in paths) {
            if ([seenHelperPaths containsObject:candidate]) continue;
            [seenHelperPaths addObject:candidate];
            NSDictionary *probe = FKHelperProbe(candidate);
            if ([probe[@"exists"] boolValue] || (selectedRoot.length && [candidate hasPrefix:selectedRoot])) [helperCandidates addObject:probe];
        }
    }
    NSArray *helperSearchDirs = @[@"usr/libexec", @"usr/bin", @"usr/sbin", @"Library/PrivilegedHelperTools"];
    NSArray *helperKeywords = @[@"helper", @"root", @"daemon", @"agent", @"service", @"privileged"];
    for (NSString *dirRel in helperSearchDirs) {
        NSString *dirPath = selectedRoot.length ? [selectedRoot stringByAppendingPathComponent:dirRel] : [@"/" stringByAppendingPathComponent:dirRel];
        NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:nil] ?: @[];
        for (NSString *name in names) {
            NSString *lower = name.lowercaseString;
            BOOL keywordHit = NO;
            for (NSString *kw in helperKeywords) if ([lower containsString:kw]) { keywordHit = YES; break; }
            if (!keywordHit) continue;
            NSString *full = [dirPath stringByAppendingPathComponent:name];
            if ([seenHelperPaths containsObject:full]) continue;
            [seenHelperPaths addObject:full];
            NSDictionary *probe = FKHelperProbe(full);
            if ([probe[@"exists"] boolValue]) [helperCandidates addObject:probe];
        }
    }

    // B. 反向关联：全量解析 LaunchDaemons plist（不按文件名过滤），读取 Program / ProgramArguments 指向的程序并校验存在性与可执行位。
    NSString *launchDaemons = selectedRoot.length ? [selectedRoot stringByAppendingPathComponent:@"Library/LaunchDaemons"] : @"";
    NSArray *launchDirs = launchDaemons.length ? @[launchDaemons] : @[];
    BOOL launchDirAccessible = NO;
    for (NSString *dirPath in launchDirs) {
        NSError *dirError = nil;
        NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:&dirError];
        if (names) launchDirAccessible = YES;
        for (NSString *name in names ?: @[]) {
            if (![name.lowercaseString hasSuffix:@".plist"]) continue;
            NSString *plistPath = [dirPath stringByAppendingPathComponent:name];
            NSData *plistData = [NSData dataWithContentsOfFile:plistPath];
            NSError *plistError = nil;
            id plistObject = plistData ? [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:nil error:&plistError] : nil;
            NSMutableDictionary *reg = [NSMutableDictionary dictionary];
            reg[@"path"] = plistPath;
            reg[@"readable"] = @(plistData != nil);
            reg[@"valid_plist"] = @([plistObject isKindOfClass:NSDictionary.class]);
            NSMutableArray *programPaths = [NSMutableArray array];
            if ([plistObject isKindOfClass:NSDictionary.class]) {
                NSDictionary *dict = (NSDictionary *)plistObject;
                reg[@"label"] = FKSafeString(dict[@"Label"]);
                id program = dict[@"Program"];
                if ([program isKindOfClass:NSString.class] && [(NSString *)program length]) [programPaths addObject:program];
                id args = dict[@"ProgramArguments"];
                if ([args isKindOfClass:NSArray.class]) {
                    for (id arg in (NSArray *)args) {
                        if ([arg isKindOfClass:NSString.class] && [(NSString *)arg length] && [(NSString *)arg hasPrefix:@"/"]) [programPaths addObject:arg];
                    }
                }
                reg[@"run_at_load"] = dict[@"RunAtLoad"] ?: NSNull.null;
                reg[@"mach_services"] = dict[@"MachServices"] ?: NSNull.null;
                reg[@"user_name"] = FKSafeString(dict[@"UserName"]);
                reg[@"group_name"] = FKSafeString(dict[@"GroupName"]);
                NSMutableArray *resolved = [NSMutableArray array];
                for (NSString *prog in programPaths) {
                    NSString *physical = [prog hasPrefix:@"/"] ? prog : [@"/" stringByAppendingString:prog];
                    if (selectedRoot.length && ![physical hasPrefix:selectedRoot]) physical = [selectedRoot stringByAppendingPathComponent:[physical substringFromIndex:1]];
                    [resolved addObject:FKHelperProbe(physical)];
                }
                reg[@"program_paths"] = resolved;
                reg[@"program"] = programPaths.firstObject ?: @"";
            }
            [helperRegistrations addObject:reg];
        }
    }

    NSUInteger executableHelpers = 0;
    for (NSDictionary *candidate in helperCandidates) if ([candidate[@"executable"] boolValue]) executableHelpers++;
    BOOL registrationResolved = NO;
    for (NSDictionary *reg in helperRegistrations) {
        for (NSDictionary *p in reg[@"program_paths"]) if ([p[@"exists"] boolValue] && [p[@"executable"] boolValue]) { registrationResolved = YES; break; }
    }
    BOOL registrationFound = helperRegistrations.count > 0;
    NSString *evidenceStatus;
    FKTestState helperState;
    if (executableHelpers > 0 && registrationResolved) { evidenceStatus = @"complete"; helperState = FKTestStatePassed; }
    else if (executableHelpers > 0) { evidenceStatus = @"partial_binary_only"; helperState = FKTestStateUnknown; }
    else if (registrationFound) { evidenceStatus = @"partial_registration_only"; helperState = FKTestStateUnknown; }
    else if (!launchDirAccessible) { evidenceStatus = @"inaccessible"; helperState = FKTestStateUnknown; }
    else { evidenceStatus = @"not_found"; helperState = FKTestStateUnknown; }
    NSString *helperDetail;
    if ([evidenceStatus isEqualToString:@"complete"]) helperDetail = @"发现可执行候选及可解析的 LaunchDaemon 声明；本版本仅完成只读预检，未启动或通信";
    else if ([evidenceStatus isEqualToString:@"partial_binary_only"]) helperDetail = @"发现可执行候选，但缺少对应的服务声明；只读探测完成";
    else if ([evidenceStatus isEqualToString:@"partial_registration_only"]) helperDetail = @"发现服务声明，但未定位到对应可执行程序；只读探测完成";
    else if ([evidenceStatus isEqualToString:@"inaccessible"]) helperDetail = @"LaunchDaemons 目录不可访问，证据不足；只读探测完成";
    else helperDetail = @"未发现符合条件的候选；未找到不等于 RootHelper 不可用，只读探测完成";
    NSDictionary *helperDiscoveryReport = [FKHelperServiceDiscovery discoveryReportForCandidates:helperCandidates];
    [self add:@"roothelper_preflight" title:@"RootHelper 按需启动前置检查" state:helperState
        detail:helperDetail
        payload:@{@"evidence_status":evidenceStatus,@"candidates":helperCandidates,@"discovery_report":helperDiscoveryReport,
                  @"launchd_registrations":helperRegistrations,@"executable_candidates":@(executableHelpers),
                  @"registration_found":@(registrationFound),@"registration_resolved":@(registrationResolved),
                  @"launchd_directory_accessible":@(launchDirAccessible),@"startup_performed":@NO,@"ipc_performed":@NO,
                  @"installation_performed":@NO,@"scope":@"read_only_preflight_only",
                  @"note":@"0.1.15 增加 IPC 消息认证、会话防重放与传输帧边界模型；仍不连接真实 Helper。"}];
    NSMutableArray *injectorPackages = [NSMutableArray array];
    NSMutableArray *suspectPackages = [NSMutableArray array];
    for (NSDictionary *package in packages) {
        NSString *packageID = FKSafeString(package[@"Package"]);
        NSString *status = FKSafeString(package[@"Status"]);
        NSString *type = FKInjectorTypeForPackage(packageID);
        BOOL installed = FKStatusInstalled(status);
        if (FKSuspectInjectorPackage(packageID) && !type) {
            [suspectPackages addObject:@{@"package_id": packageID, @"status": status,
                @"version": FKSafeString(package[@"Version"]), @"reason": @"名称包含注入器相关关键词，但未命中已知别名"}];
        }
        if (type) [injectorPackages addObject:@{@"type": type, @"package_id": packageID,
            @"status": status, @"installed": @(installed), @"version": FKSafeString(package[@"Version"]),
            @"architecture": FKSafeString(package[@"Architecture"]), @"version_source": @"dpkg_status"}];
    }
    NSMutableArray *fingerprintSpecs = [NSMutableArray array];
    NSDictionary *fingerprintMap = @{
        @"ellekit": @[@"usr/lib/libellekit.dylib"],
        @"substrate": @[@"Library/Frameworks/CydiaSubstrate.framework", @"usr/lib/libsubstrate.dylib"],
        @"substitute": @[@"usr/lib/libsubstitute.dylib", @"Library/Frameworks/Substitute.framework"],
        @"libhooker": @[@"usr/lib/libhooker.dylib", @"Library/Frameworks/libhooker.framework"],
        @"sandy": @[@"usr/lib/libsandy.dylib", @"Library/Frameworks/Sandy.framework"]
    };
    if (selectedRoot) {
        for (NSString *type in fingerprintMap) for (NSString *relative in fingerprintMap[type]) {
            NSString *full = [selectedRoot stringByAppendingPathComponent:relative];
            NSDictionary *probe = FKPathProbe(full);
            NSMutableDictionary *fp = [@{@"type": type, @"relative_path": relative, @"path": full,
                @"exists": probe[@"exists"], @"readable": probe[@"readable"], @"is_directory": probe[@"is_directory"],
                @"errno": probe[@"errno"], @"errno_name": probe[@"errno_name"], @"version": NSNull.null,
                @"version_source": @"none"} mutableCopy];
            if ([probe[@"is_directory"] boolValue]) {
                NSString *infoPath = [full stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                NSString *v = FKSafeString(info[@"CFBundleShortVersionString"]);
                if (!v.length) v = FKSafeString(info[@"CFBundleVersion"]);
                if (v.length) { fp[@"version"] = v; fp[@"version_source"] = @"framework_info_plist"; }
                fp[@"bundle_identifier"] = FKSafeString(info[@"CFBundleIdentifier"]);
            }
            [fingerprintSpecs addObject:fp];
        }
    }
    // Injection directories are recorded as ecosystem evidence, not treated as proof of an injector binary.
    NSMutableArray *injectionDirectoryProbes = [NSMutableArray array];
    if (selectedRoot) {
        for (NSString *relative in @[@"Library/ElleKit/DynamicLibraries", @"Library/MobileSubstrate/DynamicLibraries"]) {
            NSString *path = [selectedRoot stringByAppendingPathComponent:relative];
            NSDictionary *probe = FKPathProbe(path);
            [injectionDirectoryProbes addObject:@{@"path": path, @"exists": probe[@"exists"], @"readable": probe[@"readable"], @"enumerable": probe[@"enumerable"]}];
        }
    }
    NSArray *runtimeImages = FKRuntimeInjectorImages();
    NSMutableArray *detectedTypes = [NSMutableArray array];
    for (NSDictionary *pkg in injectorPackages) if ([pkg[@"installed"] boolValue] && ![detectedTypes containsObject:pkg[@"type"]]) [detectedTypes addObject:pkg[@"type"]];
    for (NSDictionary *fp in fingerprintSpecs) if ([fp[@"exists"] boolValue] && ![detectedTypes containsObject:fp[@"type"]]) [detectedTypes addObject:fp[@"type"]];
    for (NSDictionary *image in runtimeImages) if (![detectedTypes containsObject:image[@"type"]]) [detectedTypes addObject:image[@"type"]];
    NSString *primaryType = detectedTypes.firstObject ?: @"unknown";
    NSDictionary *primaryPackage = nil;
    for (NSDictionary *pkg in injectorPackages) {
        if (![pkg[@"installed"] boolValue] || ![pkg[@"type"] isEqualToString:primaryType]) continue;
        if (!primaryPackage) primaryPackage = pkg;
        if ([pkg[@"version"] isKindOfClass:NSString.class] && [pkg[@"version"] length]) { primaryPackage = pkg; break; }
    }
    NSString *version = primaryPackage[@"version"];
    NSString *versionSource = version.length ? @"dpkg_status" : @"none";
    if (!version.length) {
        for (NSDictionary *fp in fingerprintSpecs) if ([fp[@"exists"] boolValue] && [fp[@"type"] isEqualToString:primaryType] && [fp[@"version"] isKindOfClass:NSString.class] && [fp[@"version"] length]) {
            version = fp[@"version"]; versionSource = @"framework_info_plist"; break;
        }
    }
    BOOL injectorDetected = ![primaryType isEqualToString:@"unknown"];
    self.environment[@"injector"] = @{@"detected": @(injectorDetected), @"injector_type": primaryType,
        @"version": version.length ? version : NSNull.null, @"package_id": primaryPackage[@"package_id"] ?: @"",
        @"package_status": primaryPackage[@"status"] ?: @"", @"version_source": versionSource,
        @"packages": injectorPackages, @"fingerprints": fingerprintSpecs, @"injection_directories": injectionDirectoryProbes, @"runtime_images": runtimeImages,
        @"suspect_packages": suspectPackages,
        @"runtime_scope": @"仅当前 FilterKit 进程已加载镜像；不能据此判断其他 App 的注入状态",
        @"note": @"dpkg Version 优先；其次 framework Info.plist；裸 dylib 仅确认存在，不推断版本"};
    // Backward-compatible key: ellekit is populated only when evidence specifically identifies ElleKit.
    NSDictionary *ellekitPkg = nil;
    for (NSDictionary *pkg in injectorPackages) if ([pkg[@"type"] isEqualToString:@"ellekit"] && [pkg[@"installed"] boolValue]) { ellekitPkg = pkg; break; }
    NSDictionary *ellekitFP = nil;
    for (NSDictionary *fp in fingerprintSpecs) if ([fp[@"type"] isEqualToString:@"ellekit"] && [fp[@"exists"] boolValue]) { ellekitFP = fp; break; }
    BOOL ellekitRuntimeImage = NO;
    for (NSDictionary *image in runtimeImages) if ([image[@"type"] isEqualToString:@"ellekit"]) { ellekitRuntimeImage = YES; break; }
    self.environment[@"ellekit"] = @{@"detected": @(ellekitPkg != nil || ellekitFP != nil || ellekitRuntimeImage),
        @"version": ellekitPkg[@"version"] ?: (ellekitFP[@"version"] ?: NSNull.null),
        @"package_id": ellekitPkg[@"package_id"] ?: @"", @"package_status": ellekitPkg[@"status"] ?: @"",
        @"version_source": ellekitPkg ? @"dpkg_status" : (ellekitFP ? FKSafeString(ellekitFP[@"version_source"]) : @"none"),
        @"runtime_image_detected": @(ellekitRuntimeImage)};
    [self add:@"ellekit_version" title:@"注入器识别与版本" state:injectorDetected ? FKTestStatePassed : FKTestStateUnknown
        detail:injectorDetected ? [NSString stringWithFormat:@"识别到 %@；版本 %@（%@）", primaryType, version.length ? version : @"未取得", versionSource] : @"未取得足够证据；不能据此断言设备未安装注入器"
        payload:self.environment[@"injector"]];

    // 0.1.4 环境兼容性结论：基于根目录与注入器证据保守派生；证据不足归 Unknown/Partial，不因未发现 Helper 判 Failed。
    NSString *jbType = self.environment[@"jailbreak"];
    NSString *jbTypeCode = @"unknown";
    if ([jbType isEqualToString:@"RootHide"]) jbTypeCode = @"roothide";
    else if ([jbType containsString:@"Rootless"]) jbTypeCode = @"rootless";
    BOOL rootKnown = [jbTypeCode isEqualToString:@"roothide"] || [jbTypeCode isEqualToString:@"rootless"];
    id jbrootValue = self.environment[@"jbroot"];
    BOOL jbrootDetected = [jbrootValue isKindOfClass:NSString.class] && [jbrootValue length];

    NSMutableArray<NSString *> *compReasons = [NSMutableArray array];
    FKEnvironmentCompatibility comp = FKEnvironmentCompatibilityUnknown;
    if (!rootKnown) {
        comp = FKEnvironmentCompatibilityUnknown;
        [compReasons addObject:@"未取得有效的越狱根目录证据"];
    } else if (!injectorDetected) {
        comp = FKEnvironmentCompatibilityPartial;
        [compReasons addObject:@"根目录已定位，但未识别到注入器"];
    } else {
        comp = FKEnvironmentCompatibilityPassed;
        [compReasons addObject:@"根目录与注入器均已取得证据"];
    }
    self.environment[@"jailbreak_type"] = jbTypeCode;
    self.environment[@"jbroot_detected"] = @(jbrootDetected);
    self.environment[@"compatibility"] = @{
        @"status": FKCompatibilityCode(comp),
        @"state_text": FKCompatibilityText(comp),
        @"reasons": compReasons.copy
    };

    [self scanIconFallbacks];
    NSUInteger iconCount = 0, versionCount = 0;
    for (NSDictionary *app in self.apps) {
        if (![app[@"icon_source"] isEqualToString:@"unresolved"]) iconCount++;
        if ([app[@"version"] length]) versionCount++;
    }
    BOOL appAPI = self.apps.count > 0;
    [self add:@"app_enumeration" title:@"已安装 App 枚举" state:appAPI ? FKTestStatePassed : FKTestStateFailed
        detail:[NSString stringWithFormat:@"LSApplicationWorkspace：%@；获取 %lu 个应用", appAPI ? @"可调用" : @"不可用", (unsigned long)self.apps.count]
        payload:@{@"api_available": @(appAPI), @"apps_found": @(self.apps.count)}];
    [self add:@"app_metadata" title:@"App 元数据、版本与图标" state:(self.apps.count && (versionCount || iconCount)) ? FKTestStatePassed : (self.apps.count ? FKTestStateUnknown : FKTestStateFailed)
        detail:[NSString stringWithFormat:@"App %lu 个；版本 %lu 个；本机图标 %lu 个", (unsigned long)self.apps.count, (unsigned long)versionCount, (unsigned long)iconCount]
        payload:@{@"apps": self.apps, @"version_count": @(versionCount), @"icon_count": @(iconCount),
            @"icon_diagnostics": self.environment[@"app_icon_diagnostics"] ?: @{},
            @"note": @"版本优先读取 Bundle Info.plist；图标优先读取 Bundle 图标文件，再尝试签名检查后的私有 API；本 PoC 不自动发起 iTunes 网络查询"}];

    [self add:@"plugin_association" title:@"插件与 App 关联分析" state:FKTestStatePassed
        detail:[NSString stringWithFormat:@"App %lu；插件 %lu；已关联 %lu；全局 %lu；未匹配 %lu；异常 %lu",
            (unsigned long)[associationSummary[@"scanned_apps"] unsignedIntegerValue],
            (unsigned long)[associationSummary[@"discovered_plugins"] unsignedIntegerValue],
            (unsigned long)[associationSummary[@"associated_plugins"] unsignedIntegerValue],
            (unsigned long)[associationSummary[@"global_plugins"] unsignedIntegerValue],
            (unsigned long)[associationSummary[@"unmatched_plugins"] unsignedIntegerValue],
            (unsigned long)[associationSummary[@"abnormal_config"] unsignedIntegerValue]]
        payload:associationSummary];

    FKScanReport *report = [FKScanReport new]; report.tests = self.results.copy;
    report.environment = self.environment.copy; report.apps = self.apps.copy;
    report.plugins = pluginsWithSource;
    NSMutableDictionary *associationJSON = [associationResult mutableCopy] ?: [NSMutableDictionary dictionary];
    [associationJSON removeObjectForKey:@"apps"];
    [associationJSON removeObjectForKey:@"plugins"];
    report.association = associationJSON;
    // 0.1.5：把环境/注入器结构化评估写入报告；各评估独立容错，单模块异常不致整个扫描崩溃。
    report.environmentAssessment = [self environmentAssessmentJSON];
    report.injectorAssessment = [self injectorAssessmentJSON];
    report.filesystem = @{@"jbroot_candidates": self.jbRoots.copy, @"dynamic_library_candidates": self.dynamicPaths.copy,
        @"dylibs": self.dylibs.copy, @"plists": self.plists.copy, @"dpkg_package_count": @(packages.count),
        @"dpkg_packages": self.dpkgPackages.copy,
        @"dpkg_package_names": [packages valueForKey:@"Package"] ?: @[],
        @"ownership": ownership, @"dpkg_analysis": dpkgAnalysis,
        @"injector": self.environment[@"injector"] ?: @{}, @"runtime_injector_images": FKRuntimeInjectorImages(), @"injection_directories": injectionDirectoryProbes};
    return report;
}

/// 环境结构化评估：复用 EnvironmentDetector 由只读证据保守派生；异常时落保守 Unknown 字典。
- (NSDictionary *)environmentAssessmentJSON {
    NSMutableDictionary *fallback = [NSMutableDictionary dictionary];
    @try {
        FKEnvironmentModel *model = [FKEnvironmentDetector modelFromEnvironment:self.environment filesystem:nil];
        if ([model isKindOfClass:FKEnvironmentModel.class]) {
            return model.JSONDictionary ?: fallback.copy;
        }
    } @catch (NSException *exception) {
        fallback[@"compatibility"] = @{@"status": @"unknown", @"state_text": @"环境评估异常", @"reasons": @[@"环境评估模块异常，已隔离，未影响其他扫描结果"]};
    }
    return fallback.copy;
}

/// 注入器结构化画像：检测器整理识别模型，注册表补充能力画像；启停能力未验证恒 Unknown。
- (NSDictionary *)injectorAssessmentJSON {
    NSMutableDictionary *fallback = [NSMutableDictionary dictionary];
    @try {
        NSDictionary *injDict = [self.environment[@"injector"] isKindOfClass:NSDictionary.class] ? self.environment[@"injector"] : @{};
        FKInjectorModel *model = [FKInjectorDetector modelFromDictionary:injDict];
        NSMutableDictionary *json = [NSMutableDictionary dictionary];
        if ([model isKindOfClass:FKInjectorModel.class]) {
            [json addEntriesFromDictionary:model.JSONDictionary];
            FKInjectorRegistry *registry = [FKInjectorRegistry new];
            FKInjectorProfile *profile = [registry profileForInjector:model.injectorID];
            // 解析/定向/全局能力来自注册表基线规则；启停与卸载未经真实验证，保持 Unknown。
            NSString * (^cap)(BOOL) = ^(BOOL supported) { return supported ? @"Passed" : @"Failed"; };
            NSMutableDictionary *capabilities = [NSMutableDictionary dictionary];
            if (profile) {
                capabilities[@"filter_parsing"] = cap(profile.filterParsing);
                capabilities[@"app_targeting"] = cap(profile.appTargeting);
                capabilities[@"global_filter"] = cap(profile.globalInjection);
            } else {
                capabilities[@"filter_parsing"] = @"Unknown";
                capabilities[@"app_targeting"] = @"Unknown";
                capabilities[@"global_filter"] = @"Unknown";
            }
            capabilities[@"plugin_enable"] = @"Unknown";
            capabilities[@"plugin_disable"] = @"Unknown";
            capabilities[@"plugin_uninstall"] = @"Unknown";
            json[@"profile_status"] = profile ? @"Matched" : @"Unregistered";
            json[@"profile"] = profile ? profile.JSONDictionary : @{};
            json[@"capabilities"] = capabilities.copy;
        }
        return json.copy;
    } @catch (NSException *exception) {
        fallback[@"detected"] = @NO;
        fallback[@"evidence_level"] = @"unknown";
        fallback[@"note"] = @"注入器评估模块异常，已隔离，未影响其他扫描结果";
        return fallback.copy;
    }
}
@end

@implementation FKScanReport
- (NSDictionary *)JSONDictionary {
    NSMutableArray *tests = [NSMutableArray array];
    for (FKTestResult *item in self.tests) [tests addObject:item.JSONDictionary];
    NSUInteger passed = 0, failed = 0, unknown = 0;
    for (FKTestResult *item in self.tests) {
        if (item.state == FKTestStatePassed) passed++;
        else if (item.state == FKTestStateFailed) failed++;
        else unknown++;
    }
    return @{@"version": FKVersion, @"generated_at": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date],
        @"environment": self.environment ?: @{}, @"tests": tests,
        @"environment_assessment": self.environmentAssessment ?: @{},
        @"injector_assessment": self.injectorAssessment ?: @{},
        @"helper_trust": self.helperTrust ?: @{},
        @"security_report": self.securityReport ?: @{},
        @"test_summary": self.testSummary ?: @{@"executed": @NO, @"status": @"NotTested"},
        @"app_enumeration": @{@"apps_found": @(self.apps.count), @"apps": self.apps ?: @[]},
        @"filesystem": self.filesystem ?: @{},
        @"plugins": self.plugins ?: @[],
        @"association": self.association ?: @{},
        @"summary": @{@"total": @(self.tests.count), @"passed": @(passed), @"failed": @(failed), @"unknown": @(unknown)}};
}
@end
