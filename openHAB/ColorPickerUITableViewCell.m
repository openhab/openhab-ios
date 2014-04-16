//
//  ColorPickerUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "ColorPickerUITableViewCell.h"

@implementation ColorPickerUITableViewCell

@synthesize upButton, colorButton, downButton, delegate;

- (id)initWithCoder:(NSCoder *)coder
{
    NSLog(@"RollershutterUITableViewCell initWithCoder");
    self = [super initWithCoder:coder];
    if (self) {
        self.upButton = (UICircleButton *)[self viewWithTag:701];
        self.colorButton = (UICircleButton *)[self viewWithTag:702];
        self.downButton = (UICircleButton *)[self viewWithTag:703];
        UniChar upCode = 0x25b2;
        UniChar downCode = 0x25bc;
        [self.upButton setTitle:[NSString stringWithCharacters:&upCode length:1] forState:UIControlStateNormal];
        [self.downButton setTitle:[NSString stringWithCharacters:&downCode length:1] forState:UIControlStateNormal];
        [upButton addTarget:self action:@selector(upButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [colorButton addTarget:self action:@selector(colorButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [downButton addTarget:self action:@selector(downButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.separatorInset = UIEdgeInsetsZero;
    }
    return self;
}

- (void)displayWidget
{
    self.textLabel.text = [self.widget labelText];
    colorButton.backgroundColor = [self.widget.item stateAsUIColor];
}

-(void)upButtonPressed
{
    [self.widget sendCommand:@"ON"];
}

-(void)colorButtonPressed
{
    if (self.delegate != nil)
        [delegate didPressColorButton:self];
}

-(void)downButtonPressed
{
    [self.widget sendCommand:@"OFF"];
}

@end
