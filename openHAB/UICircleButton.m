//
//  UICircleButton.m
//  openHAB
//
//  Created by Victor Belov on 03/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "UICircleButton.h"

@implementation UICircleButton

UIColor *normalBackgroundColor;
UIColor *normalTextColor;

- (id)initWithCoder:(NSCoder *)coder
{
//    NSLog(@"UICircleButton initWithCoder");
    self = [super initWithCoder:coder];
    if (self) {
        self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:20];
        self.layer.cornerRadius = self.bounds.size.width/2.0;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = self.titleLabel.textColor.CGColor;
        [self addTarget:self action:@selector(buttonActionReleased) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(buttonActionTouched) forControlEvents:UIControlEventTouchDown];
        normalBackgroundColor = self.backgroundColor;
    }
    return self;
}

-(void)buttonActionReleased
{
}

-(void)buttonActionTouched
{
    self.backgroundColor = normalTextColor;
//    [self setTitleColor:normalBackgroundColor forState:UIControlStateNormal];
    normalTextColor = self.titleLabel.textColor;
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(timerTicked:) userInfo:nil repeats:NO];
}

-(void)timerTicked:(NSTimer*)timer
{
    self.backgroundColor = normalBackgroundColor;
    [self setTitleColor:normalTextColor forState:UIControlStateNormal];
    [timer invalidate];
}



@end
