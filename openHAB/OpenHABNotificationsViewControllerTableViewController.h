//
//  OpenHABNotificationsViewControllerTableViewController.h
//  openHAB
//
//  Created by Victor Belov on 24/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenHABNotificationsViewControllerTableViewController : UITableViewController

@property (nonatomic, retain) NSMutableArray *notifications;
@property (nonatomic, retain) NSString *openHABRootUrl;
@property (nonatomic, retain) NSString *openHABUsername;
@property (nonatomic, retain) NSString *openHABPassword;
@property (nonatomic) BOOL ignoreSSLCertificate;

@end
