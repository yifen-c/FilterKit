#import "FKDPKGAnalyzer.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <errno.h>
#import <stdio.h>
#import <stdint.h>

static NSString *FKDString(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}
static NSDictionary *FKDParseStatus(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!text) return @{@"records": @[], @"warnings": @[@"status_missing_or_invalid_utf8"]};
    NSMutableArray *records = [NSMutableArray array], *warnings = [NSMutableArray array];
    NSMutableDictionary *record = nil;
    NSString *current = nil;
    NSMutableSet *seen = nil;
    for (NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        if (line.length == 0 || [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length == 0) {
            if (record[@"Package"]) [records addObject:@{@"fields":[record copy]}];
            record = nil; current = nil; seen = nil; continue;
        }
        if ([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) {
            if (record && current) {
                NSString *continuation = [line substringFromIndex:1];
                record[current] = [NSString stringWithFormat:@"%@\n%@", record[current] ?: @"", continuation];
            } else if (record) [warnings addObject:@"orphan_continuation_line"];
            continue;
        }
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound || colon.location == 0) {
            if (record) [warnings addObject:@"malformed_field_line"];
            continue;
        }
        if (!record) { record=[NSMutableDictionary dictionary]; seen=[NSMutableSet set]; }
        NSString *key = [line substringToIndex:colon.location];
        NSString *lower = key.lowercaseString;
        NSUInteger start = NSMaxRange(colon);
        while (start < line.length && ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:[line characterAtIndex:start]])) start++;
        NSString *value = [line substringFromIndex:start];
        if ([seen containsObject:lower]) [warnings addObject:[@"duplicate_field:" stringByAppendingString:key]];
        [seen addObject:lower];
        // Debian field names are case-insensitive; preserve the first spelling and flag duplicates.
        NSString *canonical = nil;
        for (NSString *existing in record) if ([existing.lowercaseString isEqualToString:lower]) { canonical=existing; break; }
        record[canonical ?: key] = value;
        current = canonical ?: key;
    }
    if (record[@"Package"]) [records addObject:@{@"fields":[record copy]}];
    return @{@"records":records, @"warnings":warnings};
}
static NSString *FKDState(NSString *status, NSString **want, NSString **errorFlag, NSString **current) {
    NSArray *parts = [status componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSMutableArray *clean=[NSMutableArray array];
    for (NSString *p in parts) if (p.length) [clean addObject:p];
    *want = clean.count > 0 ? clean[0] : @"unknown";
    *errorFlag = clean.count > 1 ? clean[1] : @"unknown";
    *current = clean.count > 2 ? clean[2] : @"unknown";
    if (clean.count != 3) return @"unknown";
    if ([*errorFlag isEqualToString:@"reinstreq"]) return @"reinstreq";
    if ([*current isEqualToString:@"installed"] && [*want isEqualToString:@"install"] && [*errorFlag isEqualToString:@"ok"]) return @"installed";
    if ([*current isEqualToString:@"installed"]) return @"installed_nonstandard_status";
    if ([*current isEqualToString:@"unpacked"]) return @"unpacked";
    if ([*current isEqualToString:@"half-installed"]) return @"half-installed";
    if ([*current isEqualToString:@"half-configured"]) return @"half-configured";
    if ([*current isEqualToString:@"config-files"]) return @"config-files";
    if ([*current isEqualToString:@"not-installed"]) return @"not-installed";
    if ([*current isEqualToString:@"triggers-awaited"]) return @"triggers-awaited";
    if ([*current isEqualToString:@"triggers-pending"]) return @"triggers-pending";
    return *current;
}
static NSString *FKDCanonicalListPath(NSString *entry, NSString *root) {
    NSString *p = [entry stringByStandardizingPath];
    if (root.length && [p isEqualToString:root]) p = @"/";
    else if (root.length && [p hasPrefix:[root stringByAppendingString:@"/"]]) p = [p substringFromIndex:root.length];
    if ([p hasPrefix:@"/var/jb/"]) p = [p substringFromIndex:7];
    else if ([p isEqualToString:@"/var/jb"]) p = @"/";
    if (![p hasPrefix:@"/"]) p = [@"/" stringByAppendingString:p];
    return [p stringByStandardizingPath];
}
static NSString *FKDPluginLogicalPath(NSString *path, NSString *root) {
    NSString *p = [path stringByStandardizingPath];
    if (root.length && [p hasPrefix:root]) p = [p substringFromIndex:root.length];
    return FKDCanonicalListPath(p, nil);
}
static NSString *FKDPhysicalPath(NSString *entry, NSString *root) {
    if (!entry.length) return nil;
    NSString *p = [entry stringByStandardizingPath];
    if (root.length && [p hasPrefix:root]) return p;
    if ([p hasPrefix:@"/var/jb/"] || [p isEqualToString:@"/var/jb"]) return p;
    if (root.length && [p hasPrefix:@"/"]) return [root stringByAppendingPathComponent:[p substringFromIndex:1]];
    return p;
}
// dpkg 的 info/<package>.md5sums 固定以 MD5（32 位十六进制）记录期望校验值，
// 因此此处必须使用 MD5 与包管理器格式比对；这是完整性核对，不是安全签名用途。
// CommonCrypto 的 CC_MD5_* 流式 API 自 iOS 13 起标记 deprecated，Theos 默认 -Werror
// 会将该告警升级为编译错误。MD5 无法替换为 SHA256（会与 md5sums 期望值格式不符），
// 故仅在本函数局部抑制 -Wdeprecated-declarations，不放宽全局告警级别。
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static NSString *FKDMD5(NSString *path) {
    NSInputStream *stream=[NSInputStream inputStreamWithFileAtPath:path];
    if (!stream) return nil;
    [stream open];
    CC_MD5_CTX ctx; CC_MD5_Init(&ctx);
    uint8_t buffer[32768]; NSInteger count = 0;
    while ((count=[stream read:buffer maxLength:sizeof(buffer)]) > 0) CC_MD5_Update(&ctx, buffer, (CC_LONG)count);
    BOOL failed = stream.streamError != nil;
    [stream close];
    if (failed || count < 0) return nil;
    unsigned char digest[CC_MD5_DIGEST_LENGTH]; CC_MD5_Final(digest,&ctx);
    NSMutableString *hex=[NSMutableString stringWithCapacity:32];
    for (int i=0;i<CC_MD5_DIGEST_LENGTH;i++) [hex appendFormat:@"%02x",digest[i]];
    return hex;
}
#pragma clang diagnostic pop

// 第一级：文件头 magic 识别，返回细分格式名；未命中返回 nil。文件头优先于扩展名。
static NSString *FKDMagicFormat(const unsigned char *h, size_t n) {
    if (n >= 4) {
        uint32_t magic = ((uint32_t)h[0] << 24) | ((uint32_t)h[1] << 16) | ((uint32_t)h[2] << 8) | h[3];
        if (magic == 0xfeedface || magic == 0xfeedfacf || magic == 0xcefaedfe || magic == 0xcffaedfe) return @"mach_o";
        if (magic == 0xcafebabe || magic == 0xbebafeca || magic == 0xcafebabf || magic == 0xbfbafeca) return @"fat_macho";
    }
    if (n >= 4 && h[0]==0x7f && h[1]=='E' && h[2]=='L' && h[3]=='F') return @"elf";
    if (n >= 8 && h[0]==0x89 && h[1]=='P' && h[2]=='N' && h[3]=='G' && h[4]==0x0d && h[5]==0x0a && h[6]==0x1a && h[7]==0x0a) return @"png";
    if (n >= 3 && h[0]==0xff && h[1]==0xd8 && h[2]==0xff) return @"jpeg";
    if (n >= 4 && h[0]=='P' && h[1]=='K' && h[2]==0x03 && h[3]==0x04) return @"zip";
    if (n >= 2 && h[0]==0x1f && h[1]==0x8b) return @"gzip";
    if (n >= 6 && h[0]=='S' && h[1]=='Q' && h[2]=='L' && h[3]=='i' && h[4]=='t' && h[5]=='e') return @"sqlite";
    if (n >= 4 && h[0]=='%' && h[1]=='P' && h[2]=='D' && h[3]=='F') return @"pdf";
    if (n >= 8 && h[0]=='b' && h[1]=='p' && h[2]=='l' && h[3]=='i' && h[4]=='s' && h[5]=='t' && h[6]=='0' && h[7]=='0') return @"bplist";
    return nil;
}

// magic 细分格式归入粗类；无法归类返回 nil。
static NSString *FKDTypeFromFormat(NSString *format) {
    if ([format isEqualToString:@"mach_o"] || [format isEqualToString:@"fat_macho"] || [format isEqualToString:@"elf"]) return @"mach_o";
    if ([format isEqualToString:@"png"] || [format isEqualToString:@"jpeg"] || [format isEqualToString:@"zip"] || [format isEqualToString:@"gzip"] ||
        [format isEqualToString:@"sqlite"] || [format isEqualToString:@"pdf"] || [format isEqualToString:@"bplist"]) return @"resource";
    return nil;
}

// 第二级：内容识别。采样前若干字节，UTF-8 可读且不可打印字符占比低才判为文本。
static BOOL FKDIsLikelyTextFile(NSString *physicalPath) {
    if (physicalPath.length == 0) return NO;
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:physicalPath];
    if (!stream) return NO;
    [stream open];
    uint8_t buf[4096]; NSUInteger total = 0, nonPrintable = 0; NSInteger count = 0;
    while ((count = [stream read:buf maxLength:sizeof(buf)]) > 0) {
        for (NSInteger i = 0; i < count; i++) {
            uint8_t c = (uint8_t)buf[i]; total++;
            BOOL printable = (c >= 0x20 && c < 0x7f) || c=='\t' || c=='\n' || c=='\r' || c=='\f' || c=='\v';
            if (!printable) nonPrintable++;
        }
        if (total >= 4096) break;
    }
    [stream close];
    if (total == 0) return NO;
    return ((double)nonPrintable / (double)total) < 0.10;
}

static BOOL FKDIsConfigurationExtension(NSString *ext) {
    return [ext isEqualToString:@"plist"] || [ext isEqualToString:@"conf"] || [ext isEqualToString:@"ini"] || [ext isEqualToString:@"json"] ||
           [ext isEqualToString:@"xml"] || [ext isEqualToString:@"yaml"] || [ext isEqualToString:@"yml"] || [ext isEqualToString:@"toml"] || [ext isEqualToString:@"cfg"];
}
static BOOL FKDIsTextExtension(NSString *ext) {
    return [ext isEqualToString:@"txt"] || [ext isEqualToString:@"md"] || [ext isEqualToString:@"sh"] || [ext isEqualToString:@"py"] || [ext isEqualToString:@"rb"] ||
           [ext isEqualToString:@"js"] || [ext isEqualToString:@"strings"] || [ext isEqualToString:@"mo"];
}
static BOOL FKDIsResourceExtension(NSString *ext) {
    return [ext isEqualToString:@"png"] || [ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"] || [ext isEqualToString:@"webp"] || [ext isEqualToString:@"gif"] ||
           [ext isEqualToString:@"zst"] || [ext isEqualToString:@"zip"] || [ext isEqualToString:@"car"] || [ext isEqualToString:@"nib"] || [ext isEqualToString:@"dat"] ||
           [ext isEqualToString:@"pdf"] || [ext isEqualToString:@"ttf"] || [ext isEqualToString:@"otf"];
}

// 三级识别：magic > 内容 > 扩展名；返回粗类、细分格式、识别方式与置信度。
static NSDictionary *FKDChecksumClassify(NSString *path, NSString *physicalPath) {
    NSString *ext = path.pathExtension.lowercaseString;
    NSString *format = nil; NSString *magicType = nil;
    FILE *fp = fopen(physicalPath.fileSystemRepresentation, "rb");
    if (fp) {
        unsigned char h[16] = {0}; size_t n = fread(h, 1, sizeof(h), fp); fclose(fp);
        format = FKDMagicFormat(h, n);
        magicType = FKDTypeFromFormat(format);
    }
    if (magicType) {
        return @{@"file_type": magicType, @"format": format ?: @"", @"detection_method": @"magic", @"confidence": @"high"};
    }
    if (physicalPath.length && FKDIsLikelyTextFile(physicalPath)) {
        NSString *textType = FKDIsConfigurationExtension(ext) ? @"configuration" : @"text";
        return @{@"file_type": textType, @"format": @"text", @"detection_method": @"content", @"confidence": @"medium"};
    }
    if (FKDIsConfigurationExtension(ext)) return @{@"file_type": @"configuration", @"format": ext, @"detection_method": @"extension", @"confidence": @"medium"};
    if (FKDIsTextExtension(ext)) return @{@"file_type": @"text", @"format": ext, @"detection_method": @"extension", @"confidence": @"medium"};
    if (FKDIsResourceExtension(ext)) return @{@"file_type": @"resource", @"format": ext, @"detection_method": @"extension", @"confidence": @"medium"};
    return @{@"file_type": @"unknown", @"format": @"", @"detection_method": @"unknown", @"confidence": @"low"};
}

// 兼容旧调用：仅取粗类标签。当前校验循环已直接使用 FKDChecksumClassify；保留该符号名供静态校验与后续复用，标记 unused 避免 -Wunused-function。
static __attribute__((unused)) NSString *FKDChecksumFileType(NSString *path, NSString *physicalPath) {
    return FKDChecksumClassify(path, physicalPath)[@"file_type"];
}
static NSString *FKDExtensionKey(NSString *path) { NSString *e=path.pathExtension.lowercaseString; return e.length ? e : @"(无扩展名)"; }

@implementation FKDPKGAnalyzer
+ (NSDictionary *)analyzeStatusAtPath:(NSString *)statusPath selectedRoot:(NSString *)selectedRoot packages:(NSArray<NSDictionary *> *)packages dylibs:(NSArray<NSDictionary *> *)dylibs plists:(NSArray<NSDictionary *> *)plists {
    NSDictionary *parsed=FKDParseStatus(statusPath ?: @"");
    NSMutableDictionary *statusByID=[NSMutableDictionary dictionary];
    NSMutableArray *packageResults=[NSMutableArray array];
    NSUInteger installed=0, unpacked=0, broken=0, pluginPackages=0, packagesDylibs=0, packagesPlists=0;
    NSUInteger checksumPackages=0, totalChecksumChecked=0, totalChecksumRecords=0;
    NSString *infoDir=[[statusPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"info"];
    NSMutableDictionary<NSString *, NSMutableArray *> *owners=[NSMutableDictionary dictionary];
    NSMutableArray *missingFiles=[NSMutableArray array], *checksumMismatches=[NSMutableArray array];
    NSMutableArray *noChecksumRecords=[NSMutableArray array], *checksumUnavailable=[NSMutableArray array];
    NSMutableDictionary *checksumTypeCounts=[NSMutableDictionary dictionary], *checksumTypeTotals=[NSMutableDictionary dictionary], *checksumPathCounts=[NSMutableDictionary dictionary], *checksumExtensionCounts=[NSMutableDictionary dictionary], *checksumPackageCounts=[NSMutableDictionary dictionary];
    NSUInteger binaryMismatch=0, textMismatch=0, configMismatch=0, mutableConfigMismatch=0, resourceMismatch=0, unknownMismatch=0, configReviewMismatch=0, hardChecksumFailures=0, checksumWarnings=0;
    for (NSDictionary *raw in packages) {
        NSString *pid=FKDString(raw[@"Package"]);
        if (pid.length) statusByID[pid]=raw;
        NSString *want,*eflag,*current;
        NSString *state=FKDState(FKDString(raw[@"Status"]),&want,&eflag,&current);
        if ([state isEqual:@"installed"]) installed++;
        if ([state isEqual:@"unpacked"]) unpacked++;
        if ([state isEqual:@"half-installed"] || [state isEqual:@"half-configured"] || [state isEqual:@"reinstreq"]) broken++;
        if (!pid.length || [pid containsString:@"/"] || [pid containsString:@".."]) continue;
        NSString *listPath=[infoDir stringByAppendingPathComponent:[pid stringByAppendingString:@".list"]];
        NSData *listData=[NSData dataWithContentsOfFile:listPath];
        NSMutableArray *listed=[NSMutableArray array], *existing=[NSMutableArray array], *missing=[NSMutableArray array], *unreadable=[NSMutableArray array], *notChecked=[NSMutableArray array];
        NSMutableArray *pkgDylibs=[NSMutableArray array], *pkgFrameworks=[NSMutableArray array], *pkgPlists=[NSMutableArray array], *executables=[NSMutableArray array];
        if (listData) {
            NSString *listText=[[NSString alloc] initWithData:listData encoding:NSUTF8StringEncoding] ?: @"";
            for (NSString *line in [listText componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
                NSString *entry=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (!entry.length) continue;
                NSString *canonical=FKDCanonicalListPath(entry, selectedRoot);
                [listed addObject:canonical];
                if (!owners[canonical]) owners[canonical]=[NSMutableArray array];
                if (![owners[canonical] containsObject:pid]) [owners[canonical] addObject:pid];
                NSString *physical=FKDPhysicalPath(entry,selectedRoot);
                struct stat st = {0};
                errno = 0;
                if (physical && lstat(physical.fileSystemRepresentation,&st)==0) {
                    [existing addObject:canonical];
                    NSString *ext=physical.pathExtension.lowercaseString;
                    if ([ext isEqual:@"dylib"]) [pkgDylibs addObject:canonical];
                    if ([ext isEqual:@"plist"]) [pkgPlists addObject:canonical];
                    if ([ext isEqual:@"framework"] || [physical.lastPathComponent.lowercaseString hasSuffix:@".framework"]) [pkgFrameworks addObject:canonical];
                    if ((st.st_mode & S_IXUSR) && !S_ISDIR(st.st_mode)) [executables addObject:canonical];
                    if (S_ISDIR(st.st_mode)) [notChecked addObject:canonical];
                } else if (errno==EACCES || errno==EPERM) [unreadable addObject:canonical];
                else [missing addObject:canonical];
            }
        }
        NSString *md5Path=[infoDir stringByAppendingPathComponent:[pid stringByAppendingString:@".md5sums"]];
        NSData *md5Data=[NSData dataWithContentsOfFile:md5Path];
        NSMutableArray *checksumRecords=[NSMutableArray array];
        NSMutableSet *conffilePaths=[NSMutableSet set];
        NSString *conffiles=FKDString(raw[@"Conffiles"]);
        for (NSString *line in [conffiles componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
            NSString *trim=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if (!trim.length) continue;
            NSString *candidate=[[trim componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet] firstObject];
            if (!candidate.length) continue;
            if (![candidate hasPrefix:@"/"]) candidate=[@"/" stringByAppendingString:candidate];
            candidate=[candidate stringByStandardizingPath];
            [conffilePaths addObject:FKDCanonicalListPath(candidate, selectedRoot)];
        }
        // 标准 dpkg 另在 info/<package>.conffiles 记录配置文件清单；与 status 的 Conffiles 字段合并，避免单一渠道遗漏。
        NSString *conffilesListPath=[infoDir stringByAppendingPathComponent:[pid stringByAppendingString:@".conffiles"]];
        NSData *conffilesListData=[NSData dataWithContentsOfFile:conffilesListPath];
        if (conffilesListData) {
            NSString *cfText=[[NSString alloc] initWithData:conffilesListData encoding:NSUTF8StringEncoding] ?: @"";
            for (NSString *line in [cfText componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
                NSString *c=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
                if (!c.length) continue;
                c=[[c componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet] firstObject];
                if (!c.length) continue;
                if (![c hasPrefix:@"/"]) c=[@"/" stringByAppendingString:c];
                c=[c stringByStandardizingPath];
                [conffilePaths addObject:FKDCanonicalListPath(c, selectedRoot)];
            }
        }
        NSUInteger mismatchCount=0, checksumChecked=0;
        NSMutableDictionary *pkgChecksumStats=[NSMutableDictionary dictionary];
        if (md5Data) {
            NSString *md5Text=[[NSString alloc] initWithData:md5Data encoding:NSUTF8StringEncoding] ?: @"";
            for (NSString *line in [md5Text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
                if (line.length < 34) continue;
                NSString *expected=[[line substringToIndex:32] lowercaseString];
                if ([expected rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location != NSNotFound) continue;
                NSUInteger filenameStart = 32;
                while (filenameStart < line.length && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[line characterAtIndex:filenameStart]]) filenameStart++;
                NSString *entry = filenameStart < line.length ? [line substringFromIndex:filenameStart] : @"";
                if ([entry hasPrefix:@"*"]) entry=[entry substringFromIndex:1];
                if (!entry.length) continue;
                NSString *canonical=FKDCanonicalListPath(entry, selectedRoot);
                NSString *physical=FKDPhysicalPath(entry,selectedRoot);
                NSString *actual=physical ? FKDMD5(physical) : nil;
                NSString *result=@"not_checked";
                if (actual) {
                    checksumChecked++;
                    NSDictionary *classification=FKDChecksumClassify(canonical, physical);
                    NSString *observedType=classification[@"file_type"];
                    NSString *detMethod=classification[@"detection_method"];
                    NSString *confidence=classification[@"confidence"];
                    NSString *format=classification[@"format"];
                    checksumTypeTotals[observedType]=@([checksumTypeTotals[observedType] unsignedIntegerValue]+1);
                    result=[actual isEqualToString:expected] ? @"match" : @"mismatch";
                    if ([result isEqualToString:@"mismatch"]) {
                        mismatchCount++;
                        NSString *fileType=observedType;
                        NSString *disposition=@"hard_failure";
                        NSString *reason=@"内容与本机 md5sums 记录不一致";
                        if ([fileType isEqualToString:@"mach_o"]) {
                            disposition=@"warning";
                            reason=@"二进制内容与记录不同；可能为重签名、补丁、重定位或其他变更，本工具不判定成因";
                            binaryMismatch++; checksumWarnings++;
                            pkgChecksumStats[@"mach_o_mismatch"]=@([pkgChecksumStats[@"mach_o_mismatch"] unsignedIntegerValue]+1);
                        }
                        else if ([fileType isEqualToString:@"configuration"] && [conffilePaths containsObject:canonical]) {
                            disposition=@"mutable_config";
                            reason=@"已在 Conffiles 声明，允许本地配置差异";
                            mutableConfigMismatch++; checksumWarnings++;
                            pkgChecksumStats[@"configuration_mismatch"]=@([pkgChecksumStats[@"configuration_mismatch"] unsignedIntegerValue]+1);
                        }
                        // A plist is executable configuration consumed by launchd or an app. On-device
                        // post-install rewriting is common, but absence from Conffiles is not proof of tampering.
                        // Keep the exact MD5 evidence and request review instead of treating it as a hard failure.
                        else if ([fileType isEqualToString:@"configuration"] && [canonical.pathExtension.lowercaseString isEqualToString:@"plist"]) {
                            disposition=@"configuration_review";
                            reason=@"非 Conffiles 的 plist/配置差异，需复核；不直接判定为损坏或篡改";
                            configReviewMismatch++; checksumWarnings++;
                            pkgChecksumStats[@"configuration_mismatch"]=@([pkgChecksumStats[@"configuration_mismatch"] unsignedIntegerValue]+1);
                        }
                        else if ([fileType isEqualToString:@"configuration"]) {
                            configMismatch++; hardChecksumFailures++;
                            reason=@"非 Conffiles 配置文件内容不一致";
                            pkgChecksumStats[@"configuration_mismatch"]=@([pkgChecksumStats[@"configuration_mismatch"] unsignedIntegerValue]+1);
                            pkgChecksumStats[@"hard_failure"]=@([pkgChecksumStats[@"hard_failure"] unsignedIntegerValue]+1);
                        }
                        else if ([fileType isEqualToString:@"text"]) {
                            textMismatch++; hardChecksumFailures++;
                            reason=@"文本文件内容不一致";
                            pkgChecksumStats[@"text_mismatch"]=@([pkgChecksumStats[@"text_mismatch"] unsignedIntegerValue]+1);
                            pkgChecksumStats[@"hard_failure"]=@([pkgChecksumStats[@"hard_failure"] unsignedIntegerValue]+1);
                        }
                        else if ([fileType isEqualToString:@"resource"]) {
                            resourceMismatch++; hardChecksumFailures++;
                            reason=@"资源文件内容不一致";
                            pkgChecksumStats[@"resource_mismatch"]=@([pkgChecksumStats[@"resource_mismatch"] unsignedIntegerValue]+1);
                            pkgChecksumStats[@"hard_failure"]=@([pkgChecksumStats[@"hard_failure"] unsignedIntegerValue]+1);
                        }
                        else {
                            unknownMismatch++; checksumWarnings++; disposition=@"not_confirmed";
                            reason=@"文件类型无法可靠识别，差异未定性";
                            pkgChecksumStats[@"unknown_mismatch"]=@([pkgChecksumStats[@"unknown_mismatch"] unsignedIntegerValue]+1);
                        }
                        checksumTypeCounts[fileType]=@([checksumTypeCounts[fileType] unsignedIntegerValue]+1);
                        NSString *pathCategory=[canonical hasPrefix:@"/usr/lib/"]?@"/usr/lib":([canonical hasPrefix:@"/usr/bin/"]?@"/usr/bin":([canonical hasPrefix:@"/usr/sbin/"]?@"/usr/sbin":([canonical hasPrefix:@"/Library/"]?@"/Library":([canonical hasPrefix:@"/Applications/"]?@"/Applications":([canonical hasPrefix:@"/System/"]?@"/System":([canonical hasPrefix:@"/var/"]?@"/var":@"other"))))));
                        checksumPathCounts[pathCategory]=@([checksumPathCounts[pathCategory] unsignedIntegerValue]+1);
                        NSString *extension=FKDExtensionKey(canonical); checksumExtensionCounts[extension]=@([checksumExtensionCounts[extension] unsignedIntegerValue]+1);
                        checksumPackageCounts[pid]=@([checksumPackageCounts[pid] unsignedIntegerValue]+1);
                        [checksumMismatches addObject:@{@"package_id":pid,@"path":canonical,@"expected_md5":expected,@"actual_md5":actual,@"file_type":fileType,@"format":format ?: @"",@"detection_method":detMethod,@"confidence":confidence,@"disposition":disposition,@"reason":reason,@"path_category":pathCategory,@"extension":extension,@"conffile_declared":@([conffilePaths containsObject:canonical])}];
                    }
                } else {
                    [checksumUnavailable addObject:@{@"package_id":pid,@"path":canonical,@"reason":@"file_unreadable_or_missing"}];
                }
                [checksumRecords addObject:@{@"path":canonical,@"expected_md5":expected,@"actual_md5":actual ?: [NSNull null],@"result":result}];
            }
        }
        if (listData && md5Data) {
            NSMutableSet *checksumPaths=[NSMutableSet set];
            for (NSDictionary *cr in checksumRecords) if ([cr[@"path"] isKindOfClass:NSString.class]) [checksumPaths addObject:cr[@"path"]];
            for (NSString *listedPath in listed) if (![checksumPaths containsObject:listedPath])
                [noChecksumRecords addObject:@{@"package_id":pid,@"path":listedPath,@"reason":@"no_checksum_record"}];
        }
        if (md5Data) checksumPackages++;
        totalChecksumChecked += checksumChecked;
        totalChecksumRecords += checksumRecords.count;
        NSDictionary *checksumStats=@{
            @"checked":@(checksumChecked),
            @"matched":@(checksumChecked>=mismatchCount?checksumChecked-mismatchCount:0),
            @"mach_o_mismatch":pkgChecksumStats[@"mach_o_mismatch"] ?: @0,
            @"configuration_mismatch":pkgChecksumStats[@"configuration_mismatch"] ?: @0,
            @"text_mismatch":pkgChecksumStats[@"text_mismatch"] ?: @0,
            @"resource_mismatch":pkgChecksumStats[@"resource_mismatch"] ?: @0,
            @"unknown_mismatch":pkgChecksumStats[@"unknown_mismatch"] ?: @0,
            @"hard_failure":pkgChecksumStats[@"hard_failure"] ?: @0};
        NSDictionary *r=@{@"package_id":pid, @"version":FKDString(raw[@"Version"]), @"architecture":FKDString(raw[@"Architecture"]),
            @"status":FKDString(raw[@"Status"]), @"want":want ?: @"unknown", @"error_flag":eflag ?: @"unknown", @"current_state":current ?: @"unknown",
            @"state":state, @"raw_fields":raw, @"maintainer":FKDString(raw[@"Maintainer"]), @"description":FKDString(raw[@"Description"]),
            @"depends":FKDString(raw[@"Depends"]), @"pre_depends":FKDString(raw[@"Pre-Depends"]), @"recommends":FKDString(raw[@"Recommends"]),
            @"suggests":FKDString(raw[@"Suggests"]), @"provides":FKDString(raw[@"Provides"]), @"conflicts":FKDString(raw[@"Conflicts"]),
            @"replaces":FKDString(raw[@"Replaces"]), @"source":FKDString(raw[@"Source"]), @"section":FKDString(raw[@"Section"]),
            @"essential":FKDString(raw[@"Essential"]), @"homepage":FKDString(raw[@"Homepage"]),
            @"list_path":listPath, @"list_readable":@(listData!=nil), @"listed_file_count":@(listed.count),
            @"existing_files":existing, @"missing_files":missing, @"unreadable_files":unreadable, @"not_checked_files":notChecked,
            @"dylibs":pkgDylibs, @"frameworks":pkgFrameworks, @"plists":pkgPlists, @"executables":executables,
            @"md5sums_path":md5Path, @"md5sums_available":@(md5Data!=nil), @"checksum_records":checksumRecords,
            @"checksum_checked":@(checksumChecked), @"checksum_mismatches":@(mismatchCount), @"checksum_stats":checksumStats,
            @"note":@"dpkg .list 是包管理器记录的路径清单；文件存在性是独立实测，目录不计算为普通文件校验。"};
        [packageResults addObject:r];
        if (pkgDylibs.count || pkgPlists.count || pkgFrameworks.count) pluginPackages++;
        if (pkgDylibs.count) packagesDylibs++;
        if (pkgPlists.count) packagesPlists++;
        [missingFiles addObjectsFromArray:missing];
    }
    NSMutableArray *fileOwnership=[NSMutableArray array], *conflicts=[NSMutableArray array];
    for (NSString *path in owners) {
        NSArray *ids=owners[path];
        [fileOwnership addObject:@{@"path":path,@"packages":ids,@"conflict":@(ids.count>1)}];
        if (ids.count>1) [conflicts addObject:@{@"path":path,@"packages":ids}];
    }
    NSUInteger unownedPluginFiles=0;
    for (NSDictionary *item in [dylibs arrayByAddingObjectsFromArray:plists]) {
        NSString *path=FKDString(item[@"path"]);
        NSString *canonical=nil;
        canonical=FKDPluginLogicalPath(path, selectedRoot);
        if (!owners[canonical]) unownedPluginFiles++;
    }
    NSUInteger mismatchTotal=checksumMismatches.count;
    NSArray *sortedPackageKeys=[[checksumPackageCounts allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) { return [checksumPackageCounts[b] compare:checksumPackageCounts[a]]; }];
    NSMutableArray *packageDistribution=[NSMutableArray array]; for (NSString *key in sortedPackageKeys) [packageDistribution addObject:@{@"package_id":key,@"mismatches":checksumPackageCounts[key]}];
    NSUInteger binaryTotal=[checksumTypeTotals[@"mach_o"] unsignedIntegerValue];
    double binaryMismatchRate=binaryTotal ? ((double)binaryMismatch/(double)binaryTotal) : 0.0;
    NSUInteger unknownTotal=[checksumTypeTotals[@"unknown"] unsignedIntegerValue];
    double checksumCoverage=totalChecksumRecords ? ((double)totalChecksumChecked/(double)totalChecksumRecords) : 0.0;
    NSDictionary *checksumAnalysis=@{@"records":@(totalChecksumRecords),@"checked":@(totalChecksumChecked),@"coverage":@(checksumCoverage),@"mismatch_total":@(mismatchTotal),@"matched":@(totalChecksumChecked>=mismatchTotal?totalChecksumChecked-mismatchTotal:0),@"file_type_totals":checksumTypeTotals,@"unknown_type_total":@(unknownTotal),@"by_file_type":checksumTypeCounts,@"binary_total":@(binaryTotal),@"binary_mismatch_rate":@(binaryMismatchRate),@"by_path_category":checksumPathCounts,@"by_extension":checksumExtensionCounts,@"by_package":packageDistribution,@"mach_o_mismatches":@(binaryMismatch),@"text_mismatches":@(textMismatch),@"configuration_mismatches":@(configMismatch),@"configuration_review_mismatches":@(configReviewMismatch),@"mutable_config_mismatches":@(mutableConfigMismatch),@"resource_mismatches":@(resourceMismatch),@"unknown_mismatches":@(unknownMismatch),@"hard_failures":@(hardChecksumFailures),@"warnings":@(checksumWarnings),@"not_confirmed":@(unknownMismatch+configReviewMismatch),@"policy":@"Mach-O mismatch is warning only; declared Conffiles mismatch is mutable-config warning; non-Conffiles plist mismatch is configuration_review (not a hard failure without independent evidence); other text/config/resource mismatch is hard failure; unknown type is not-confirmed. Original MD5 evidence is retained."};
    NSDictionary *summary=@{@"total_packages":@(packages.count),@"installed_packages":@(installed),@"unpacked_packages":@(unpacked),
        @"broken_packages":@(broken),@"plugin_packages":@(pluginPackages),@"packages_with_dylibs":@(packagesDylibs),
        @"packages_with_plists":@(packagesPlists),@"unowned_plugin_files":@(unownedPluginFiles),
        @"missing_package_files":@(missingFiles.count),@"checksum_packages":@(checksumPackages),
        @"checksum_records":@(totalChecksumRecords),@"checksum_checked":@(totalChecksumChecked),
        @"checksum_mismatches":@(mismatchTotal),@"no_checksum_record":@(noChecksumRecords.count),
        @"checksum_unavailable":@(checksumUnavailable.count),@"checksum_hard_failures":@(hardChecksumFailures),@"checksum_warnings":@(checksumWarnings),@"ownership_conflicts":@(conflicts.count),
        @"status_parse_warnings":parsed[@"warnings"] ?: @[], @"parsed_status_stanzas":@([parsed[@"records"] count])};
    return @{@"summary":summary,@"packages":packageResults,@"file_ownership":fileOwnership,
        @"integrity":@{@"missing_files":missingFiles,@"checksum_mismatches":checksumMismatches,
            @"no_checksum_record":noChecksumRecords,@"checksum_unavailable":checksumUnavailable,@"checksum_analysis":checksumAnalysis,@"checksum_algorithm":@"MD5 (仅对 info/*.md5sums 中列出的文件；不是安全签名)"},
        @"status_path":statusPath ?: @"",@"info_directory":infoDir ?: @"",
        @"evidence_note":@"包归属以 .list 精确路径为主；RootHide 的 jbroot 物理路径与包管理器逻辑路径分开保存。未匹配路径不以文件名猜测归属。"};
}
@end
