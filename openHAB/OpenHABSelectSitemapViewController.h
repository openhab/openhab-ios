//
//  OpenHABSelectSitemapViewController.h
//  openHAB
//
//  Created by Victor Belov on 14/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenHABSelectSitemapViewController : UITableViewController


@property (nonatomic, retain) NSMutableArray *sitemaps;
@property (nonatomic, retain) NSString *openHABRootUrl;
@property (nonatomic, retain) NSString *openHABUsername;
@property (nonatomic, retain) NSString *openHABPassword;
@property (nonatomic) BOOL ignoreSSLCertificate;

@end
