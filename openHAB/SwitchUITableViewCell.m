//
//  SwitchUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "SwitchUITableViewCell.h"
#import "OpenHABWidget.h"
#import "OpenHABItem.h"

@implementation SwitchUITableViewCell
@synthesize widgetSwitch;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.widgetSwitch = (UISwitch *)[self viewWithTag:200];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.separatorInset = UIEdgeInsetsZero;
    }
    return self;
}

- (void)displayWidget
{
    self.textLabel.text = [self.widget labelText];
    if ([self.widget labelValue] != nil)
        self.detailTextLabel.text = [self.widget labelValue];
    else
        self.detailTextLabel.text = nil;
    if ([self.widget.item.state isEqualToString:@"ON"]) {
        [self.widgetSwitch setOn:YES];
    } else {
        [self.widgetSwitch setOn:NO];
    }
//    NSLog(@"%f %f %f %f", self.textLabel.frame.origin.x, self.textLabel.frame.origin.y, self.textLabel.frame.size.width, self.textLabel.frame.size.height);
    [self.widgetSwitch addTarget:self action:@selector(switchChange:) forControlEvents:UIControlEventValueChanged];
}

- (void)switchChange:(id)sender{
    if (self.widgetSwitch.isOn) {
        NSLog(@"Switch to ON");
        [self.widget sendCommand:@"ON"];
    } else {
        NSLog(@"Switch to OFF");
        [self.widget sendCommand:@"OFF"];
    }
}

@end
