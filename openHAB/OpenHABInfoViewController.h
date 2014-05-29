//
//  OpenHABInfoViewController.h
//  openHAB
//
//  Created by Victor Belov on 27/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenHABInfoViewController : UITableViewController

@property (nonatomic, retain) IBOutlet UILabel *appVersionLabel;
@property (nonatomic, retain) IBOutlet UILabel *openHABVersionLabel;
@property (nonatomic, retain) IBOutlet UILabel *openHABUUIDLabel;
@property (nonatomic, retain) IBOutlet UILabel *openHABSecretLabel;

@end
