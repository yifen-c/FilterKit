#import "FKScanner.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <dirent.h>
#import <errno.h>
#import <unistd.h>
#import <string.h>

static NSString * const FKVersion = @"0.0.1";

static NSDictionary *FKPathProbe(NSString *path) {
    struct stat st;
    errno = 0;
    BOOL exists = (stat(path.fileSystemRepresentation, &st) == 0);
    int statError = exists ? 0 : errno;
    BOOL isDirectory = exists && S_ISDIR(st.st_mode);
    errno = 0;
    BOOL readable = exists && access(path.fileSystemRepresentation, R_OK) == 0;
    int readError = readable ? 0 : (exists ? errno : statError);
    NSInteger count = -1;
    int enumError = 0;
    if (isDirectory && readable) {
        errno = 0;
        DIR *dir = opendir(path.fileSystemRepresentation);
        if (dir) {
            count = 0;
            struct dirent *entry = NULL;
            while ((entry = readdir(dir)) != NULL) {
                if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) count++;
            }
            closedir(dir);
        } else {
            enumError = errno;
        }
    }
    return @{
        @"path": path ?: @"",
        @"exists": @(exists),
        @"is_directory": @(isDirectory),
        @"readable": @(readable),
        @"enumerable": @(count >= 0),
        @"entry_count": @(count),
        @"errno": @(exists ? (count >= 0 || !isDirectory ? 0 : enumError) : statError),
        @"read_errno": @(readError),
        @"enumerate_errno": @(enumError),
        @"error": exists ? (count < 0 && isDirectory ? [NSString stringWithFormat:@"目录枚举失败：%@", [NSError errorWithDomain:NSPOSIXErrorDomain code:enumError userInfo:nil].localizedDescription] : @"") :
            [NSString stringWithFormat:@"路径探测失败：%@", [NSError errorWithDomain:NSPOSIXErrorDomain code:statError userInfo:nil].localizedDescription]
    };
}

static NSArray<NSDictionary *> *FKReadDpkgStatus(NSString *statusPath) {
    NSString *content = [NSString stringWithContentsOfFile:statusPath encoding:NSUTF8StringEncoding error:nil];
    if (!content.length) return @[];
    NSMutableArray *records = [NSMutableArray array];
    for (NSString *paragraph in [content componentsSeparatedByString:@"\n\n"]) {
        NSMutableDictionary *record = [NSMutableDictionary dictionary];
        NSString *currentKey = nil;
        for (NSString *line in [paragraph componentsSeparatedByString:@"\n"]) {
            if ([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) {
                if (currentKey) record[currentKey] = [NSString stringWithFormat:@"%@\n%@", record[currentKey] ?: @"", [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
                continue;
            }
            NSRange range = [line rangeOfString:@": "];
            if (range.location != NSNotFound) {
                currentKey = [line substringToIndex:range.location];
                record[currentKey] = [line substringFromIndex:range.location + 2];
            }
        }
        if (record[@"Package"]) [records addObject:record];
    }
    return records;
}

static id FKSendObject(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static NSString *FKStringValue(id object, SEL selector) {
    id value = FKSendObject(object, selector);
    return [value isKindOfClass:NSString.class] ? value : nil;
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
@end

@implementation FKScanner

- (void)add:(NSString *)identifier title:(NSString *)title state:(FKTestState)state detail:(NSString *)detail payload:(NSDictionary *)payload {
    [self.results addObject:[FKTestResult resultWithID:identifier title:title state:state detail:detail payload:payload]];
}

- (FKScanReport *)runScan {
    self.results = [NSMutableArray array];
    self.apps = [NSMutableArray array];
    self.jbRoots = [NSMutableArray array];
    self.dynamicPaths = [NSMutableArray array];
    self.dylibs = [NSMutableArray array];
    self.plists = [NSMutableArray array];
    self.dpkgPackages = [NSMutableArray array];
    self.environment = [NSMutableDictionary dictionary];

    struct utsname machineInfo;
    NSString *machineArch = @"unknown";
    if (uname(&machineInfo) == 0) {
        machineArch = [NSString stringWithUTF8String:machineInfo.machine] ?: @"unknown";
    }
    self.environment[@"ios_version"] = UIDevice.currentDevice.systemVersion ?: @"unknown";
    self.environment[@"architecture"] = machineArch;
    self.environment[@"jailbreak"] = @"unknown";
    self.environment[@"ellekit"] = @{@"version": NSNull.null, @"package_id": @"", @"package_status": @"", @"version_source": @"", @"detection_status": @"unknown"};

    // 1. 探测所有 JBROOT 候选，不因首个成功路径而提前结束。
    NSArray *rootCandidates = @[@"/var/jb", @"/var/rootless", @"/private/var/jb"];
    for (NSString *path in rootCandidates) [self.jbRoots addObject:FKPathProbe(path)];
    BOOL rootFound = NO;
    NSMutableArray<NSString *> *validRoots = [NSMutableArray array];
    for (NSDictionary *item in self.jbRoots) {
        if ([item[@"exists"] boolValue] && [item[@"is_directory"] boolValue]) {
            rootFound = YES;
            [validRoots addObject:item[@"path"]];
        }
    }
    self.environment[@"jailbreak"] = rootFound ? @"RootHide/Rootless（待环境确认）" : @"unknown";
    [self add:@"jbroot" title:@"JBROOT 候选路径" state:rootFound ? FKTestStatePassed : FKTestStateFailed
        detail:[NSString stringWithFormat:@"探测 %lu 个候选，发现 %lu 个目录", (unsigned long)rootCandidates.count, (unsigned long)validRoots.count]
        payload:@{@"candidates": self.jbRoots}];

    // 2. 探测冻结路径，并额外检查 ElleKit 官方构建中出现的大小写路径。
    for (NSString *root in validRoots) {
        NSArray *suffixes = @[
            @"library/MobileSubstrate/DynamicLibraries",
            @"Library/ElleKit/DynamicLibraries",
            @"Library/MobileSubstrate/DynamicLibraries"
        ];
        for (NSString *suffix in suffixes) {
            NSString *path = [root stringByAppendingPathComponent:suffix];
            [self.dynamicPaths addObject:FKPathProbe(path)];
        }
    }
    BOOL dynamicReadable = NO;
    for (NSDictionary *item in self.dynamicPaths) if ([item[@"readable"] boolValue] && [item[@"is_directory"] boolValue]) dynamicReadable = YES;
    [self add:@"dynamic_paths" title:@"DynamicLibraries 目录访问" state:dynamicReadable ? FKTestStatePassed : FKTestStateFailed
        detail:[NSString stringWithFormat:@"检查 %lu 个候选目录，%s", (unsigned long)self.dynamicPaths.count, dynamicReadable ? "至少一个可读取" : "没有可读取目录"]
        payload:@{@"candidates": self.dynamicPaths}];

    // 3. 枚举 dylib。
    for (NSDictionary *item in self.dynamicPaths) {
        if (![item[@"readable"] boolValue] || ![item[@"is_directory"] boolValue]) continue;
        NSString *path = item[@"path"];
        NSArray *names = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:nil] copy];
        for (NSString *name in names) {
            if (name.pathExtension.length && [name.pathExtension.lowercaseString isEqualToString:@"dylib"]) {
                [self.dylibs addObject:@{@"name": name, @"path": [path stringByAppendingPathComponent:name]}];
            }
        }
    }
    [self add:@"dylib_scan" title:@"dylib 文件枚举" state:self.dylibs.count ? FKTestStatePassed : (dynamicReadable ? FKTestStatePassed : FKTestStateFailed)
        detail:[NSString stringWithFormat:@"发现 %lu 个 dylib", (unsigned long)self.dylibs.count]
        payload:@{@"count": @(self.dylibs.count), @"files": self.dylibs}];

    // 4、5. 读取 plist 并验证 ElleKit Filter 字典结构。
    NSUInteger readablePlists = 0, validFilters = 0;
    for (NSDictionary *item in self.dynamicPaths) {
        if (![item[@"readable"] boolValue] || ![item[@"is_directory"] boolValue]) continue;
        NSString *dir = item[@"path"];
        NSArray *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil] ?: @[];
        for (NSString *name in names) {
            if (![name.pathExtension.lowercaseString isEqualToString:@"plist"]) continue;
            NSString *path = [dir stringByAppendingPathComponent:name];
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (!data) continue;
            readablePlists++;
            NSError *error = nil;
            id object = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
            NSDictionary *filter = [object isKindOfClass:NSDictionary.class] ? object[@"Filter"] : nil;
            BOOL valid = [filter isKindOfClass:NSDictionary.class];
            if (valid) validFilters++;
            [self.plists addObject:@{@"name": name, @"path": path, @"readable": @YES, @"has_filter_dictionary": @(valid),
                                     @"bundles_count": @([filter[@"Bundles"] isKindOfClass:NSArray.class] ? [filter[@"Bundles"] count] : 0),
                                     @"executables_count": @([filter[@"Executables"] isKindOfClass:NSArray.class] ? [filter[@"Executables"] count] : 0),
                                     @"parse_error": error.localizedDescription ?: @""}];
        }
    }
    [self add:@"plist_read" title:@"plist 文件读取" state:readablePlists ? FKTestStatePassed : (dynamicReadable ? FKTestStateUnknown : FKTestStateFailed)
        detail:[NSString stringWithFormat:@"成功读取 %lu 个 plist", (unsigned long)readablePlists]
        payload:@{@"count": @(readablePlists), @"files": self.plists}];
    [self add:@"filter_parse" title:@"ElleKit Filter 配置解析" state:validFilters ? FKTestStatePassed : (readablePlists ? FKTestStateFailed : FKTestStateUnknown)
        detail:[NSString stringWithFormat:@"%lu 个 plist 含有效 Filter 字典", (unsigned long)validFilters]
        payload:@{@"valid_filter_count": @(validFilters), @"plist_count": @(readablePlists)}];

    // 6、7、8. dpkg 数据与 ElleKit 包版本。
    NSString *statusPath = nil;
    for (NSString *root in validRoots) {
        NSString *candidate = [root stringByAppendingPathComponent:@"var/lib/dpkg/status"];
        if ([NSFileManager.defaultManager isReadableFileAtPath:candidate]) { statusPath = candidate; break; }
    }
    NSArray *packages = statusPath ? FKReadDpkgStatus(statusPath) : @[];
    [self.dpkgPackages addObjectsFromArray:packages];
    [self add:@"dpkg_status" title:@"dpkg status 读取" state:statusPath ? FKTestStatePassed : (validRoots.count ? FKTestStateFailed : FKTestStateUnknown)
        detail:statusPath ? [NSString stringWithFormat:@"读取 %lu 个包记录", (unsigned long)packages.count] : @"未找到可读取的 status 文件"
        payload:@{@"path": statusPath ?: @"", @"package_count": @(packages.count)}];

    NSUInteger ownershipFiles = 0;
    for (NSDictionary *package in packages) {
        NSString *packageID = package[@"Package"];
        if (!packageID.length) continue;
        for (NSString *root in validRoots) {
            NSString *listPath = [[root stringByAppendingPathComponent:@"var/lib/dpkg/info"] stringByAppendingPathComponent:[packageID stringByAppendingString:@".list"]];
            if ([NSFileManager.defaultManager isReadableFileAtPath:listPath]) ownershipFiles++;
        }
    }
    [self add:@"dpkg_ownership" title:@"dpkg 包文件归属数据" state:ownershipFiles ? FKTestStatePassed : FKTestStateUnknown
        detail:[NSString stringWithFormat:@"发现 %lu 个可读取的包文件清单", (unsigned long)ownershipFiles]
        payload:@{@"readable_list_files": @(ownershipFiles), @"note": @"Conffiles 不是完整安装文件清单；优先检查 info/*.list"}];

    NSDictionary *ellekit = nil;
    for (NSDictionary *package in packages) {
        NSString *packageID = [package[@"Package"] lowercaseString];
        if ([packageID isEqualToString:@"ellekit"] || [packageID containsString:@"ellekit"]) {
            ellekit = package;
            break;
        }
    }
    if (ellekit) {
        self.environment[@"ellekit"] = @{@"version": ellekit[@"Version"] ?: NSNull.null,
                                         @"package_id": ellekit[@"Package"] ?: @"",
                                         @"package_status": ellekit[@"Status"] ?: @"",
                                         @"version_source": statusPath ?: @"",
                                         @"detection_status": @"detected"};
    }
    [self add:@"ellekit_version" title:@"ElleKit 版本识别" state:ellekit ? FKTestStatePassed : FKTestStateUnknown
        detail:ellekit ? [NSString stringWithFormat:@"%@ (%@)", ellekit[@"Version"] ?: @"unknown", ellekit[@"Package"] ?: @""] : @"未从 dpkg status 确认 ElleKit 包版本"
        payload:self.environment[@"ellekit"]];

    // 9、10. 通过运行时私有 API 尝试枚举应用；不将 API 可调用等同于所有数据均可读取。
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = FKSendObject(workspaceClass, NSSelectorFromString(@"defaultWorkspace"));
    id proxies = FKSendObject(workspace, NSSelectorFromString(@"allApplications"));
    BOOL apiAvailable = [proxies isKindOfClass:NSArray.class];
    NSUInteger iconCount = 0;
    if (apiAvailable) {
        for (id proxy in proxies) {
            NSString *bundleID = FKStringValue(proxy, NSSelectorFromString(@"applicationIdentifier"));
            if (!bundleID.length) continue;
            NSString *name = FKStringValue(proxy, NSSelectorFromString(@"localizedName")) ?: bundleID;
            NSString *version = FKStringValue(proxy, NSSelectorFromString(@"applicationVersion")) ?: @"";
            NSURL *bundleURL = FKSendObject(proxy, NSSelectorFromString(@"bundleURL"));
            NSMutableDictionary *app = [@{@"bundle_id": bundleID, @"name": name, @"version": version,
                                          @"bundle_path": bundleURL.path ?: @"",
                                          @"is_system": @([bundleURL.path hasPrefix:@"/Applications/"] || [bundleURL.path hasPrefix:@"/System/"])} mutableCopy];
            SEL iconSelector = NSSelectorFromString(@"iconDataForVariant:withOptions:");
            if ([proxy respondsToSelector:iconSelector]) {
                NSMethodSignature *signature = [proxy methodSignatureForSelector:iconSelector];
                if (!signature) continue;
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                NSUInteger variant = 2;
                NSDictionary *options = @{};
                invocation.target = proxy;
                invocation.selector = iconSelector;
                [invocation setArgument:&variant atIndex:2];
                [invocation setArgument:&options atIndex:3];
                [invocation invoke];
                __unsafe_unretained id iconData = nil;
                [invocation getReturnValue:&iconData];
                if ([iconData isKindOfClass:NSData.class] && [UIImage imageWithData:iconData]) iconCount++;
            }
            [self.apps addObject:app];
        }
    }
    [self add:@"app_enumeration" title:@"已安装 App 枚举" state:self.apps.count ? FKTestStatePassed : FKTestStateFailed
        detail:[NSString stringWithFormat:@"LSApplicationWorkspace：%@；获取 %lu 个应用", apiAvailable ? @"可调用" : @"不可用", (unsigned long)self.apps.count]
        payload:@{@"api_available": @(apiAvailable), @"apps_found": @(self.apps.count)}];
    [self add:@"app_metadata" title:@"App 元数据与图标读取" state:(self.apps.count && iconCount) ? FKTestStatePassed : (self.apps.count ? FKTestStateUnknown : FKTestStateFailed)
        detail:[NSString stringWithFormat:@"元数据 %lu 个；成功读取图标 %lu 个", (unsigned long)self.apps.count, (unsigned long)iconCount]
        payload:@{@"apps": self.apps, @"icon_count": @(iconCount), @"icon_api": @"iconDataForVariant:withOptions:"}];

    FKScanReport *report = [FKScanReport new];
    report.tests = self.results.copy;
    report.environment = self.environment.copy;
    report.apps = self.apps.copy;
    report.filesystem = @{@"jbroot_candidates": self.jbRoots.copy, @"dynamic_library_candidates": self.dynamicPaths.copy,
                          @"dylibs": self.dylibs.copy, @"plists": self.plists.copy, @"dpkg_package_count": @(packages.count)};
    return report;
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
    return @{
        @"version": FKVersion,
        @"generated_at": [NSISO8601DateFormatter new].stringFromDate(NSDate.date),
        @"environment": self.environment ?: @{},
        @"tests": tests,
        @"app_enumeration": @{@"apps_found": @(self.apps.count), @"apps": self.apps ?: @[]},
        @"filesystem": self.filesystem ?: @{},
        @"summary": @{@"total": @(self.tests.count), @"passed": @(passed), @"failed": @(failed), @"unknown": @(unknown)}
    };
}
@end
