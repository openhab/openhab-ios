//
//  OpenHABDrawerTableViewController.h
//  openHAB
//
//  Created by Victor Belov on 23/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenHABDrawerTableViewController : UITableViewController

@property (nonatomic, retain) NSMutableArray *sitemaps;
@property (nonatomic, retain) NSString *openHABRootUrl;
@property (nonatomic, retain) NSString *openHABUsername;
@property (nonatomic, retain) NSString *openHABPassword;
@property (nonatomic) BOOL ignoreSSLCertificate;
@property (nonatomic) NSUInteger cellCount;
@property (nonatomic) NSMutableArray *drawerItems;

@end
