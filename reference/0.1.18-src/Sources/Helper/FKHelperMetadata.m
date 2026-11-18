#import "FKHelperMetadata.h"

static BOOL FKIsNonEmptyString(id value) {
    return [value isKindOfClass:NSString.class] && [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0;
}

static BOOL FKIsBooleanNumber(id value) {
    if (![value isKindOfClass:NSNumber.class]) return NO;
    double numeric = [(NSNumber *)value doubleValue];
    return numeric == 0.0 || numeric == 1.0;
}

@implementation FKHelperMetadata

- (instancetype)init {
    if ((self = [super init])) {
        _packageIDs = @[];
        _missingFields = @[];
        _validationIssues = @[];
        _fileType = @"unknown";
        _candidateSchemaValid = YES;
    }
    return self;
}

+ (instancetype)metadataFromCandidate:(NSDictionary *)candidate {
    FKHelperMetadata *metadata = [[self alloc] init];
    if (![candidate isKindOfClass:NSDictionary.class]) {
        metadata.candidateSchemaValid = NO;
        metadata.validationIssues = @[@"candidate_not_dictionary"];
        return metadata;
    }

    NSMutableArray<NSString *> *issues = [NSMutableArray array];
    id pathValue = candidate[@"path"];
    metadata.path = [pathValue isKindOfClass:NSString.class] ? [(NSString *)pathValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    metadata.pathIsAbsolute = metadata.path.length > 1 && [metadata.path hasPrefix:@"/"];
    NSArray<NSString *> *components = metadata.path.pathComponents;
    metadata.pathHasTraversal = [components containsObject:@".."];
    if (!metadata.pathIsAbsolute) [issues addObject:@"path_not_absolute"];
    if (metadata.pathHasTraversal) [issues addObject:@"path_contains_traversal"];

    id logical = candidate[@"logical_path"];
    if (logical && ![logical isKindOfClass:NSString.class]) [issues addObject:@"logical_path_type_invalid"];
    metadata.logicalPath = [logical isKindOfClass:NSString.class] ? logical : nil;
    if (metadata.logicalPath.length && [[metadata.logicalPath pathComponents] containsObject:@".."]) {
        [issues addObject:@"logical_path_contains_traversal"];
    }

    id exists = candidate[@"exists"];
    id regular = candidate[@"regular_file"];
    id executable = candidate[@"executable"];
    if (!FKIsBooleanNumber(exists)) [issues addObject:@"exists_type_invalid"];
    if (!FKIsBooleanNumber(regular)) [issues addObject:@"regular_file_type_invalid"];
    if (!FKIsBooleanNumber(executable)) [issues addObject:@"executable_type_invalid"];
    metadata.exists = FKIsBooleanNumber(exists) ? [exists boolValue] : NO;
    metadata.regularFile = FKIsBooleanNumber(regular) ? [regular boolValue] : NO;
    metadata.executable = FKIsBooleanNumber(executable) ? [executable boolValue] : NO;

    id sizeValue = candidate[@"size"];
    if (sizeValue && ![sizeValue isKindOfClass:NSNumber.class]) [issues addObject:@"size_type_invalid"];
    metadata.size = [sizeValue isKindOfClass:NSNumber.class] ? [sizeValue longLongValue] : 0;
    if (metadata.size < 0) [issues addObject:@"size_negative"];

    id fileType = candidate[@"file_type"];
    if (fileType && ![fileType isKindOfClass:NSString.class]) [issues addObject:@"file_type_type_invalid"];
    metadata.fileType = [fileType isKindOfClass:NSString.class] ? [(NSString *)fileType lowercaseString] : (metadata.regularFile ? @"regular" : @"unknown");
    if (![metadata.fileType isEqualToString:@"unknown"] && ![metadata.fileType isEqualToString:@"regular"]) {
        [issues addObject:@"file_type_not_regular"];
    }

    id packages = candidate[@"package_ids"];
    NSMutableArray<NSString *> *packageIDs = [NSMutableArray array];
    if (packages && ![packages isKindOfClass:NSArray.class]) [issues addObject:@"package_ids_type_invalid"];
    if ([packages isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)packages) {
            if (FKIsNonEmptyString(item)) [packageIDs addObject:[(NSString *)item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
            else [issues addObject:@"package_id_entry_invalid"];
        }
    }
    metadata.packageIDs = [[NSOrderedSet orderedSetWithArray:packageIDs] array];

    id version = candidate[@"version"];
    metadata.version = [version isKindOfClass:NSString.class] ? version : nil;
    if (version && ![version isKindOfClass:NSString.class]) [issues addObject:@"version_type_invalid"];
    id identifier = candidate[@"helper_id"] ?: candidate[@"bundle_id"];
    metadata.identifier = [identifier isKindOfClass:NSString.class] ? identifier : nil;
    if (identifier && ![identifier isKindOfClass:NSString.class]) [issues addObject:@"identifier_type_invalid"];
    id protocolVersion = candidate[@"protocol_version"];
    metadata.protocolVersion = [protocolVersion isKindOfClass:NSNumber.class] ? [protocolVersion integerValue] : 0;
    if (protocolVersion && ![protocolVersion isKindOfClass:NSNumber.class]) [issues addObject:@"protocol_version_type_invalid"];
    if (metadata.protocolVersion < 0) [issues addObject:@"protocol_version_negative"];

    // 只读检查：不打开、不执行、不修改候选文件。
    metadata.readable = metadata.exists && metadata.candidateSchemaValid && metadata.pathIsAbsolute && !metadata.pathHasTraversal && metadata.regularFile && metadata.path.length > 0 && [[NSFileManager defaultManager] isReadableFileAtPath:metadata.path];

    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    if (!FKIsNonEmptyString(metadata.version)) [missing addObject:@"version"];
    if (!FKIsNonEmptyString(metadata.identifier)) [missing addObject:@"identifier"];
    if (metadata.packageIDs.count == 0) [missing addObject:@"package_id"];
    if (metadata.protocolVersion <= 0) [missing addObject:@"protocol_version"];
    metadata.missingFields = missing.copy;
    metadata.validationIssues = issues.copy;
    metadata.candidateSchemaValid = issues.count == 0;
    return metadata;
}

- (NSDictionary *)JSONDictionary {
    return @{
        @"path": self.path ?: @"", @"logical_path": self.logicalPath ?: @"",
        @"exists": @(self.exists), @"regular_file": @(self.regularFile),
        @"executable": @(self.executable), @"readable": @(self.readable),
        @"size": @(self.size), @"package_ids": self.packageIDs ?: @[],
        @"version": self.version ?: @"", @"identifier": self.identifier ?: @"",
        @"protocol_version": @(self.protocolVersion), @"missing_fields": self.missingFields ?: @[],
        @"validation_issues": self.validationIssues ?: @[], @"file_type": self.fileType ?: @"unknown",
        @"path_is_absolute": @(self.pathIsAbsolute), @"path_has_traversal": @(self.pathHasTraversal),
        @"candidate_schema_valid": @(self.candidateSchemaValid),
        @"system_tool_candidate": @(self.systemToolCandidate)
    };
}

@end
