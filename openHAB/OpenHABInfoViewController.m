//
//  OpenHABInfoViewController.m
//  openHAB
//
//  Created by Victor Belov on 27/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABInfoViewController.h"
#import <GAI.h>
#import "GAIFields.h"
#import "GAIDictionaryBuilder.h"

@interface OpenHABInfoViewController ()

@end

@implementation OpenHABInfoViewController
@synthesize appVersionLabel, openHABVersionLabel, openHABUUIDLabel, openHABSecretLabel;

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSString * appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString * versionBuildString = [NSString stringWithFormat:@"%@ (%@)", appVersionString, appBuildString];
    appVersionLabel.text = versionBuildString;
    openHABVersionLabel.text = @"-";
    openHABUUIDLabel.text = @"-";
    openHABSecretLabel.text = @"-";
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    id tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName
           value:@"OpenHABInfoViewController"];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadOpenHABInfo
{
/*    NSURL *pageToLoadUrl = [[NSURL alloc] initWithString:self.pageUrl];
    NSMutableURLRequest *pageRequest = [NSMutableURLRequest requestWithURL:pageToLoadUrl];
    [pageRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
    currentPageOperation = [[AFHTTPRequestOperation alloc] initWithRequest:pageRequest];
    if (self.ignoreSSLCertificate) {
        NSLog(@"Warning - ignoring invalid certificates");
        currentPageOperation.securityPolicy.allowInvalidCertificates = YES;
    }
    [currentPageOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSData *response = (NSData*)responseObject;
        NSError *error;
    } failure:^(AFHTTPRequestOperation *operation, NSError *error){
        NSLog(@"Error:------>%@", [error description]);
        NSLog(@"error code %ld",(long)[operation.response statusCode]);
    }];
    [currentPageOperation start];
*/
}

@end
