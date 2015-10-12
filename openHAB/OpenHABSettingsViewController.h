//
//  OpenHABSettingsViewController.h
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OpenHABAppDelegate.h"

@interface OpenHABSettingsViewController : UITableViewController <OpenHABAppDataDelegate, UITextFieldDelegate>
{
    IBOutlet UITextField *localUrlTextField;
    IBOutlet UITextField *remoteUrlTextField;
    IBOutlet UITextField *usernameTextField;
    IBOutlet UITextField *passwordTextField;
    IBOutlet UISwitch *ignoreSSLSwitch;
    IBOutlet UISwitch *demomodeSwitch;
    IBOutlet UISwitch *idleOffSwitch;
    IBOutlet UITableView *settingsTableView;
    
    NSString *settingsLocalUrl;
    NSString *settingsRemoteUrl;
    NSString *settingsUsername;
    NSString *settingsPassword;
    BOOL settingsIgnoreSSL;
    BOOL settingsDemomode;
    BOOL settingsIdleOff;
}

@property (nonatomic, retain) UITextField *localUrlTextField;
@property (nonatomic, retain) UITextField *remoteUrlTextField;
@property (nonatomic, retain) UITextField *usernameTextField;
@property (nonatomic, retain) UITextField *passwordTextField;
@property (nonatomic, retain) UISwitch *ignoreSSLSwitch;
@property (nonatomic, retain) UISwitch *demomodeSwitch;
@property (nonatomic, retain) UISwitch *idleOffSwitch;
@property (nonatomic, retain) NSString *settingsLocalUrl;
@property (nonatomic, retain) NSString *settingsRemoteUrl;
@property (nonatomic, retain) NSString *settingsUsername;
@property (nonatomic, retain) NSString *settingsPassword;
@property (nonatomic, assign) BOOL settingsIgnoreSSL;
@property (nonatomic, assign) BOOL settingsDemomode;
@property (nonatomic, assign) BOOL settingsIdleOff;

@end
