//
//  GenericUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 15/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <UIKit/UIKit.h>
@class OpenHABWidget;

@interface GenericUITableViewCell : UITableViewCell
{
    OpenHABWidget * widget;
}

- (void)loadWidget:(OpenHABWidget *)widgetToLoad;
- (void)displayWidget;

@property (nonatomic, retain) OpenHABWidget *widget;

@end
