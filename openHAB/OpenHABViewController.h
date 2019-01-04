//
//  OpenHABViewController.h
//  openHAB
//
//  Created by Victor Belov on 12/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OpenHABTracker.h"
#import "OpenHABSitemapPage.h"
#import "AFRememberingSecurityPolicy.h"

@class OpenHABSitemapPage;
@interface OpenHABViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, OpenHABTrackerDelegate, OpenHABSitemapPageDelegate, OpenHABSelectionTableViewControllerDelegate, ColorPickerUITableViewCellDelegate, ImageUITableViewCellDelegate, AFRememberingSecurityPolicyDelegate>
{
    OpenHABTracker *tracker;
}


@property (nonatomic,retain) IBOutlet UITableView *widgetTableView;
@property (nonatomic, strong) NSString *pageUrl;
@property (nonatomic, strong) NSString *openHABRootUrl;
@property (nonatomic, strong) NSString *openHABUsername;
@property (nonatomic, strong) NSString *openHABPassword;
@property (nonatomic, strong) NSString *defaultSitemap;
@property (nonatomic) BOOL ignoreSSLCertificate;
@property (nonatomic) BOOL idleOff;
@property (nonatomic, retain) NSMutableArray *sitemaps;
@property (nonatomic, retain) OpenHABSitemapPage *currentPage;
@property (nonatomic, retain) UIPickerView *selectionPicker;
@property (nonatomic) NetworkStatus pageNetworkStatus;
@property (nonatomic) BOOL pageNetworkStatusAvailable;
@property NSInteger toggle;
@property (nonatomic, strong) NSString *deviceToken;
@property (nonatomic, strong) NSString *deviceId;
@property (nonatomic, strong) NSString *deviceName;
@property (nonatomic, retain) NSString *atmosphereTrackingId;
@property (nonatomic, retain) UIRefreshControl *refreshControl;

- (void)openHABTracked:(NSString *)openHABUrl;
- (void)sendCommand:(OpenHABItem *)item commandToSend:(NSString *)command;

@end
