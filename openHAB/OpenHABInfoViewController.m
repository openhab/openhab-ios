//
//  OpenHABInfoViewController.m
//  openHAB
//
//  Created by Victor Belov on 27/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABInfoViewController.h"

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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
