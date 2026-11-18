#import "FKHelperPeerBinding.h"

static BOOL FKIsLowerHexDigest(NSString *value) {
    if (![value isKindOfClass:NSString.class] || value.length != 64) return NO;
    NSData *ascii = [value dataUsingEncoding:NSASCIIStringEncoding];
    if (ascii.length != 64) return NO;
    const char *bytes = ascii.bytes;
    if (bytes == NULL) return NO;
    for (NSUInteger i = 0; i < 64; i++) {
        char c = bytes[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return NO;
    }
    return YES;
}

@implementation FKHelperPeerBinding
- (instancetype)initWithSessionID:(NSString *)sessionID clientID:(NSString *)clientID helperID:(NSString *)helperID
                    helperBuildID:(NSString *)helperBuildID credentialDigest:(NSString *)credentialDigest
                  transcriptDigest:(NSString *)transcriptDigest {
    if (![sessionID isKindOfClass:NSString.class] || sessionID.length == 0 || sessionID.length > 128 ||
        ![clientID isKindOfClass:NSString.class] || clientID.length == 0 || clientID.length > 255 ||
        ![helperID isKindOfClass:NSString.class] || helperID.length == 0 || helperID.length > 255 ||
        ![helperBuildID isKindOfClass:NSString.class] || helperBuildID.length == 0 || helperBuildID.length > 128 ||
        !FKIsLowerHexDigest(credentialDigest) || !FKIsLowerHexDigest(transcriptDigest)) return nil;
    self = [super init];
    if (self) {
        _sessionID = [sessionID copy]; _clientID = [clientID copy]; _helperID = [helperID copy];
        _helperBuildID = [helperBuildID copy]; _credentialDigest = [credentialDigest copy];
        _transcriptDigest = [transcriptDigest copy];
    }
    return self;
}
- (BOOL)matchesExpectedHelperID:(NSString *)expectedHelperID expectedBuildID:(NSString *)expectedBuildID
             expectedCredential:(NSString *)expectedCredentialDigest {
    return [expectedHelperID isKindOfClass:NSString.class] && expectedHelperID.length > 0 &&
        [expectedBuildID isKindOfClass:NSString.class] && expectedBuildID.length > 0 &&
        FKIsLowerHexDigest(expectedCredentialDigest) &&
        [self.helperID isEqualToString:expectedHelperID] &&
        [self.helperBuildID isEqualToString:expectedBuildID] &&
        [self.credentialDigest isEqualToString:expectedCredentialDigest];
}
- (NSDictionary *)JSONDictionary {
    return @{ @"sessionID": self.sessionID, @"clientID": self.clientID, @"helperID": self.helperID,
              @"helperBuildID": self.helperBuildID, @"credentialDigest": self.credentialDigest,
              @"transcriptDigest": self.transcriptDigest };
}
@end
