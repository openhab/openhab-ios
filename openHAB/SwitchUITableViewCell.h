//
//  SwitchUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"

@interface SwitchUITableViewCell : GenericUITableViewCell
{
    UISwitch *widgetSwitch;
}
@property (nonatomic, retain) UISwitch *widgetSwitch;

@end
