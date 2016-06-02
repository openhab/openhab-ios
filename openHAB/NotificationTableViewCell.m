//
//  NotificationTableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 02/06/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//

#import "NotificationTableViewCell.h"

@implementation NotificationTableViewCell
@synthesize textLabel, detailTextLabel;

- (id)initWithCoder:(NSCoder *)coder
{
    NSLog(@"DrawerUITableViewCell initWithCoder");
    self = [super initWithCoder:coder];
    if (self) {
        self.separatorInset = UIEdgeInsetsZero;
        self.textLabel = (UILabel *)[self viewWithTag:101];
        self.detailTextLabel =(UILabel *)[self viewWithTag:102];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

// This is to fix possible different sizes of user icons - we fix size and position of UITableViewCell icons
- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = CGRectMake(14,6,30,30);
}

@end
