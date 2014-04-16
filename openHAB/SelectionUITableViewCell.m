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

- (void)loadWidget:(OpenHABWidget *)widgetToLoad
{
    self.widget = widgetToLoad;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.selectionStyle = UITableViewCellSelectionStyleBlue;
}

- (void)displayWidget
{
    self.textLabel.text = [self.widget labelText];
    int selectedMapping = [self.widget mappingIndexByCommand:self.widget.item.state];
    if (selectedMapping != -1) {
        OpenHABWidgetMapping *widgetMapping = [widget.mappings objectAtIndex:selectedMapping];
        self.detailTextLabel.text = widgetMapping.label;
    }
}

@end
