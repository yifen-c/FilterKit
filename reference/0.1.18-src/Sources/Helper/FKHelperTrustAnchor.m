#import "FKHelperTrustAnchor.h"

@implementation FKHelperTrustAnchor
- (instancetype)initWithKeyID:(NSString *)keyID algorithm:(NSString *)algorithm
                 publicKeyData:(NSData *)publicKeyData environment:(NSString *)environment
                      testOnly:(BOOL)testOnly {
    self = [super init];
    if (self) {
        _keyID = [keyID isKindOfClass:NSString.class] ? [keyID copy] : @"";
        _algorithm = [algorithm isKindOfClass:NSString.class] ? [algorithm copy] : @"";
        _publicKeyData = [publicKeyData isKindOfClass:NSData.class] ? [publicKeyData copy] : [NSData data];
        _environment = [environment isKindOfClass:NSString.class] ? [environment copy] : @"";
        _provisioningSource = @"caller_supplied";
        _testOnly = testOnly;
    }
    return self;
}
- (BOOL)isStructurallyValid {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9._-]{1,64}$" options:0 error:nil];
    BOOL keyIDValid = self.keyID.length > 0 && [regex numberOfMatchesInString:self.keyID options:0 range:NSMakeRange(0, self.keyID.length)] == 1;
    BOOL algorithmValid = [@[@"ed25519", @"p256_sha256"] containsObject:self.algorithm];
    return keyIDValid && algorithmValid && self.publicKeyData.length >= 32 &&
        [@[@"release", @"test"] containsObject:self.environment];
}
- (BOOL)isUsableForProduction {
    return [self isStructurallyValid] && !self.testOnly && [self.environment isEqualToString:@"release"] && [self.provisioningSource isEqualToString:@"embedded_bundle"];
}
- (NSDictionary *)JSONDictionary {
    return @{ @"keyID": self.keyID ?: @"", @"algorithm": self.algorithm ?: @"",
              @"environment": self.environment ?: @"", @"provisioningSource": self.provisioningSource ?: @"caller_supplied", @"testOnly": @(self.testOnly),
              @"publicKeyConfigured": @(self.publicKeyData.length > 0) };
}
@end

@implementation FKHelperTrustAnchorStore
- (instancetype)init { return [self initWithAnchors:@[]]; }
- (instancetype)initWithAnchors:(NSArray<FKHelperTrustAnchor *> *)anchors {
    self = [super init];
    if (self) {
        NSMutableArray *accepted = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        for (FKHelperTrustAnchor *value in ([anchors isKindOfClass:NSArray.class] ? anchors : @[])) {
            if (![value isKindOfClass:FKHelperTrustAnchor.class] || ![value isStructurallyValid]) continue;
            if ([seen containsObject:value.keyID]) continue;
            [seen addObject:value.keyID];
            [accepted addObject:value];
        }
        _anchors = accepted.copy;
        _policyVersion = @"1.1";
    }
    return self;
}
- (FKHelperTrustAnchor *)anchorForKeyID:(NSString *)keyID {
    if (![keyID isKindOfClass:NSString.class] || keyID.length == 0) return nil;
    for (FKHelperTrustAnchor *anchor in self.anchors) if ([anchor.keyID isEqualToString:keyID]) return anchor;
    return nil;
}
- (FKHelperTrustAnchor *)productionAnchorForKeyID:(NSString *)keyID {
    FKHelperTrustAnchor *anchor = [self anchorForKeyID:keyID];
    return anchor.isUsableForProduction ? anchor : nil;
}
- (BOOL)hasProductionAnchor {
    for (FKHelperTrustAnchor *anchor in self.anchors) if (anchor.isUsableForProduction) return YES;
    return NO;
}
- (NSDictionary *)JSONDictionary {
    NSMutableArray *items = [NSMutableArray array];
    for (FKHelperTrustAnchor *anchor in self.anchors) [items addObject:anchor.JSONDictionary];
    NSUInteger productionCount = 0;
    for (FKHelperTrustAnchor *anchor in self.anchors) if (anchor.isUsableForProduction) productionCount++;
    return @{ @"policyVersion": self.policyVersion, @"anchorCount": @(items.count),
              @"productionAnchorCount": @(productionCount), @"anchors": items.copy };
}
@end
