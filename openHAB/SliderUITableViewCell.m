//
//  SliderUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "SliderUITableViewCell.h"
#import "OpenHABWidget.h"
#import "OpenHABItem.h"

@implementation SliderUITableViewCell
@synthesize widgetSlider;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.widgetSlider = (UISlider *)[self viewWithTag:400];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.separatorInset = UIEdgeInsetsZero;
    }
    return self;
}

- (void)displayWidget
{
    self.textLabel.text = [self.widget labelText];
    float widgetValue = [widget.item stateAsFloat];
    [self.widgetSlider setValue:widgetValue/100];
    [self.widgetSlider addTarget:self
                  action:@selector(sliderDidEndSliding:)
        forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
}

- (void)sliderDidEndSliding:(NSNotification *)notification {
    NSLog(@"Slider new value = %f", self.widgetSlider.value);
    int intValue = self.widgetSlider.value * 100;
    [self.widget sendCommand:[NSString stringWithFormat:@"%d", intValue]];
}

@end
