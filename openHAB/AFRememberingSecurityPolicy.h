//
//  AFRememberingSecurityPolicy.h
//  openHAB
//
//  Created by Victor Belov on 14/07/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "AFSecurityPolicy.h"
@class AFRememberingSecurityPolicy;
@protocol AFRememberingSecurityPolicyDelegate <NSObject>

// delegate should ask user for a decision on what to do with invalid certificate
- (void) evaluateServerTrust:(AFRememberingSecurityPolicy *)policy summary:(NSString *)certificateSummary forDomain:(NSString *)domain;
// certificate received from openHAB doesn't match our record, ask user for a decision
- (void) evaluateCertificateMismatch:(AFRememberingSecurityPolicy *)policy summary:(NSString *)certificateSummary forDomain:(NSString *)domain;

@end

@interface AFRememberingSecurityPolicy : AFSecurityPolicy


+ (void) initializeCertificatesStore;
+ (NSString *) getPersistensePath;
+ (void) saveTrustedCertificates;
- (void) deny;
- (void) permitOnce;
- (void) permitAlways;
@property (nonatomic, retain) id <AFRememberingSecurityPolicyDelegate> delegate;
@property (nonatomic) int evaluateResult;

@end
