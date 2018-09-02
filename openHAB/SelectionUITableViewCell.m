//
//  SelectionUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 27/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "SelectionUITableViewCell.h"
#import "OpenHABWidget.h"
#import "OpenHABItem.h"
#import "OpenHABWidgetMapping.h"

@implementation SelectionUITableViewCell

- (void)setWidget:(OpenHABWidget *)widget
{
    super.widget = widget;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.selectionStyle = UITableViewCellSelectionStyleBlue;
}

- (void)displayWidget
{
    self.textLabel.text = [self.widget labelText];
    NSUInteger selectedMapping = [self.widget mappingIndexByCommand:self.widget.item.state];
    if (selectedMapping != NSNotFound) {
        OpenHABWidgetMapping *widgetMapping = [widget.mappings objectAtIndex:selectedMapping];
        self.detailTextLabel.text = widgetMapping.label;
    }
}

@end
