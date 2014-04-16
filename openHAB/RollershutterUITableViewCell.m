//
//  RollershutterUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 27/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "RollershutterUITableViewCell.h"
#import <QuartzCore/QuartzCore.h>
#import "OpenHABWidget.h"

@implementation RollershutterUITableViewCell
@synthesize upButton, stopButton, downButton;

- (id)initWithCoder:(NSCoder *)coder
{
    NSLog(@"RollershutterUITableViewCell initWithCoder");
    self = [super initWithCoder:coder];
    if (self) {
        self.upButton = (UIButton *)[self viewWithTag:601];
        self.stopButton = (UIButton *)[self viewWithTag:602];
        self.downButton = (UIButton *)[self viewWithTag:603];
        UniChar upCode = 0x25b2;
        UniChar stopCode = 0x25a0;
        UniChar downCode = 0x25bc;
        [self.upButton setTitle:[NSString stringWithCharacters:&upCode length:1] forState:UIControlStateNormal];
        [self.stopButton setTitle:[NSString stringWithCharacters:&stopCode length:1] forState:UIControlStateNormal];
        [self.downButton setTitle:[NSString stringWithCharacters:&downCode length:1] forState:UIControlStateNormal];
        [upButton addTarget:self action:@selector(upButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [stopButton addTarget:self action:@selector(stopButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [downButton addTarget:self action:@selector(downButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.separatorInset = UIEdgeInsetsZero;
    }
    return self;
}

-(void)upButtonPressed
{
    NSLog(@"up button pressed");
    [self.widget sendCommand:@"UP"];
}

-(void)stopButtonPressed
{
    NSLog(@"stop button pressed");
    [self.widget sendCommand:@"STOP"];
}

-(void)downButtonPressed
{
    NSLog(@"down button pressed");
    [self.widget sendCommand:@"DOWN"];
}

@end
