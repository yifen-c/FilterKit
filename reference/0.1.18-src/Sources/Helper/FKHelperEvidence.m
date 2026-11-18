#import "FKHelperEvidence.h"

@implementation FKHelperEvidence

- (NSDictionary *)JSONDictionary {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    return @{
        @"path": self.path ?: @"",
        @"file_type": self.fileType ?: @"unknown",
        @"package_id": self.packageID ?: @"",
        @"package_source": self.packageSource ?: @"unknown",
        @"version": self.version ?: @"",
        @"executable": @(self.executable),
        @"file_digest": self.fileDigest ?: @"",
        @"code_signature": self.codeSignature ?: @"",
        @"signer_subject": self.signerSubject ?: @"",
        @"trust_chain_source": self.trustChainSource ?: @"none",
        @"checked_at": [formatter stringFromDate:self.checkedAt ?: [NSDate date]]
    };
}

@end
