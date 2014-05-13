//
//  GenericUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 15/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OpenHABWidget.h"

@interface GenericUITableViewCell : UITableViewCell
{
    OpenHABWidget * widget;
}

- (void)loadWidget:(OpenHABWidget *)widgetToLoad;
- (void)displayWidget;

@property (nonatomic, retain) OpenHABWidget *widget;
@property (nonatomic, retain) UILabel *textLabel;
@property (nonatomic, retain) UILabel *detailTextLabel;
@property (nonatomic, retain) NSArray *disclosureConstraints;

@end
