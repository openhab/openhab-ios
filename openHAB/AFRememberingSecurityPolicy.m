//
//  AFRememberingSecurityPolicy.m
//  openHAB
//
//  Created by Victor Belov on 14/07/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "AFRememberingSecurityPolicy.h"

@implementation AFRememberingSecurityPolicy
@synthesize delegate;

static NSMutableDictionary * trustedCertificates;

// Init an AFRememberingSecurityPolicy and set ignore certificates setting
- (AFRememberingSecurityPolicy *)initWithIgnoreCertificates:(BOOL)ignoreCertificates
{
    self = [super init];
    self.allowInvalidCertificates = ignoreCertificates;
    return self;
}

+ (void) initializeCertificatesStore
{
    NSLog(@"Initializing cert store");
    [self loadTrustedCertificates];
    if (trustedCertificates == nil) {
        NSLog(@"No cert store, creating");
        trustedCertificates = [[NSMutableDictionary alloc] init];
//        [trustedCertificates setObject:@"Bulk" forKey:@"Bulk id to make it non-empty"];
        [self saveTrustedCertificates];
    } else {
        NSLog(@"Loaded existing cert store");
    }
}

+ (void) storeCertificateData:(CFDataRef)certificate forDomain:(NSString*)domain
{
//    NSData *certificateData = [NSKeyedArchiver archivedDataWithRootObject:(__bridge id)(certificate)];
    NSData *certificateData = (__bridge_transfer NSData*) certificate;
    [trustedCertificates setObject:certificateData forKey:domain];
    [self saveTrustedCertificates];
}

+ (CFDataRef) certificateDataForDomain:(NSString*)domain
{
    NSData *certificateData = [trustedCertificates objectForKey:domain];
    if (certificateData == nil)
        return nil;
    CFDataRef certificate = CFDataCreate(NULL, [certificateData bytes], [certificateData length]);
//    CFDataRef certificate = SecCertificateCopyData((__bridge CFDataRef)([NSKeyedUnarchiver unarchiveObjectWithData:certificateData]));
    return certificate;
}

+ (NSString *) getPersistensePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"trustedCertificates"];
    return filePath;
}

+ (void) loadTrustedCertificates
{
    trustedCertificates = [NSKeyedUnarchiver unarchiveObjectWithFile:[self getPersistensePath]];
}

+ (void) saveTrustedCertificates
{
    [NSKeyedArchiver archiveRootObject:trustedCertificates toFile:[self getPersistensePath]];
}

- (BOOL) evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain
// Evaluates trust received during SSL negotiation and checks it against known ones,
// against policy setting to ignore certificate errors and so on.
{
    SecTrustResultType evaluateResult;
    SecTrustEvaluate(serverTrust, &evaluateResult);
    if (evaluateResult == kSecTrustResultUnspecified || evaluateResult == kSecTrustResultProceed || self.allowInvalidCertificates) {
        // This means system thinks this is a legal/usable certificate, just permit the connection
        return YES;
    }
    SecCertificateRef certificate = SecTrustGetLeafCertificate(serverTrust);
    CFStringRef certificateSummary = SecCertificateCopySubjectSummary(certificate);
    CFDataRef certificateData = SecCertificateCopyData(certificate);
    // If we have a certificate for this domain
    if ([AFRememberingSecurityPolicy certificateDataForDomain:domain] != nil && certificateData != nil) {
        // Obtain certificate we have and compare it with the certificate presented by the server
        CFDataRef previousCertificateData = [AFRememberingSecurityPolicy certificateDataForDomain:domain];
        BOOL success = CFEqual(previousCertificateData, certificateData);
        if (success) {
            // If certificate matched one in our store - permit this connection
            return YES;
        } else {
            // We have a certificate for this domain in our memory of decisions, but the certificate we've got now
            // differs. We need to warn user about possible MiM attack and wait for users decision.
            // TODO: notify user and wait for decision
            if (self.delegate != nil) {
                self.evaluateResult = -1;
                [delegate evaluateCertificateMismatch:self summary:(__bridge NSString *)(certificateSummary) forDomain:domain];
                while (self.evaluateResult == -1) {
                    [NSThread sleepForTimeInterval:0.1];
                }
                switch (self.evaluateResult) {
                    case 0:
                        // User decided to abort connection
                        return NO;
                        break;
                    case 1:
                        // User decided to accept invalid certificate once
                        return YES;
                        break;
                    case 2:
                        // User decided to accept invalid certificate and remember decision
                        // Add certificate to storage
                        [AFRememberingSecurityPolicy storeCertificateData:certificateData forDomain:domain];
                        return YES;
                        break;
                    default:
                        // Something went wrong, abort connection
                        return NO;
                        break;
                }
            }
            return NO;
        }
    }
    // Warn user about invalid certificate and wait for user's decision
    if (delegate != nil) {
        // Delegate should ask user for decision
        self.evaluateResult = -1;
        [delegate evaluateServerTrust:self summary:(__bridge NSString *)(certificateSummary) forDomain:domain];
        // Wait until we get response from delegate with user's decision
        while (self.evaluateResult == -1) {
            [NSThread sleepForTimeInterval:0.1];
        }
        switch (self.evaluateResult) {
            case 0:
                // User decided to abort connection
                return NO;
                break;
            case 1:
                // User decided to accept invalid certificate once
                return YES;
                break;
            case 2:
                // User decided to accept invalid certificate and remember decision
                // Add certificate to storage
                [AFRememberingSecurityPolicy storeCertificateData:certificateData forDomain:domain];
                return YES;
                break;
            default:
                // Something went wrong, abort connection
                return NO;
                break;
        }
    }
    // We have no way of handling it so no access!
    return NO;
}

- (void) permitOnce
{
    self.evaluateResult = 1;
}

- (void) permitAlways
{
    self.evaluateResult = 2;
}

- (void) deny
{
    self.evaluateResult = 0;
}

SecCertificateRef SecTrustGetLeafCertificate(SecTrustRef trust)
// Returns the leaf certificate from a SecTrust object (that is always the
// certificate at index 0).
{
    SecCertificateRef   result;
    
    assert(trust != NULL);
    
    if (SecTrustGetCertificateCount(trust) > 0) {
        result = SecTrustGetCertificateAtIndex(trust, 0);
        assert(result != NULL);
    } else {
        result = NULL;
    }
    return result;
}


@end
