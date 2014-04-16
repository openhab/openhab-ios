//
//  OpenHABSelectionTableViewController.h
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OpenHABItem.h"

@class OpenHABSelectionTableViewController;

@protocol OpenHABSelectionTableViewControllerDelegate <NSObject>
- (void)didSelectWidgetMapping:(int)selectedMapping;
@end

@interface OpenHABSelectionTableViewController : UITableViewController

@property (nonatomic, retain) NSMutableArray *mappings;
@property (nonatomic, retain) id <OpenHABSelectionTableViewControllerDelegate> delegate;
@property (nonatomic, retain) OpenHABItem *selectionItem;

@end
