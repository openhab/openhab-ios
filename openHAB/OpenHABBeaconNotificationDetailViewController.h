//
//  OpenHABBeaconNotificationDetailViewController.h
//  openHAB
//
//  Created by Uwe on 03.06.16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OpenHABBeaconNotification.h"
#import "OpenHABBeaconNotificationTableViewController.h"

@interface OpenHABBeaconNotificationDetailViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate>

@property (strong, nonatomic) OpenHABBeaconNotification* detailItem;


@property (nonatomic, retain) NSMutableArray *items;
@property (nonatomic, retain) NSString *openHABRootUrl;
@property (nonatomic, retain) NSString *openHABUsername;
@property (nonatomic, retain) NSString *openHABPassword;
@property (nonatomic) BOOL ignoreSSLCertificate;
@property (nonatomic, retain) UIPickerView *itemPicker;


- (void)setDetailItem:(OpenHABBeaconNotification*)newDetailItem;

@end

