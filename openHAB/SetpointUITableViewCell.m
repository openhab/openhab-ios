//
//  SetpointUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "SetpointUITableViewCell.h"
#import "OpenHABWidget.h"
#import "OpenHABItem.h"

@implementation SetpointUITableViewCell
{
}
@synthesize widgetSegmentedControl, textLabel;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.widgetSegmentedControl = (UISegmentedControl *)[self viewWithTag:300];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.separatorInset = UIEdgeInsetsZero;
    }
    return self;
}

- (void)displayWidget
{
    self.textLabel.text = [self.widget labelText];
    NSString *widgetValue;
    if ([self.widget.item.state isEqual:@"Uninitialized"]) {
        widgetValue = @"N/A";
    } else {
        widgetValue = [NSString stringWithFormat:@"%.01f", [self.widget.item stateAsFloat]];
    }
    [self.widgetSegmentedControl setTitle:widgetValue forSegmentAtIndex:1];
    [self.widgetSegmentedControl addTarget:self
                         action:@selector(pickOne:)
               forControlEvents:UIControlEventValueChanged];
}

-(void) pickOne:(id)sender
{
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    NSLog(@"Setpoint pressed %d", [segmentedControl selectedSegmentIndex]);
    // Deselect segment in the middle
    if ([segmentedControl selectedSegmentIndex] == 1) {
        [self.widgetSegmentedControl setSelectedSegmentIndex:-1];
    // - pressed
    } else if ([segmentedControl selectedSegmentIndex] == 0) {
        if ([self.widget.item.state isEqual:@"Uninitialized"]) {
            [self.widget sendCommand:(NSString*)self.widget.minValue];
        } else {
            if (self.widget.minValue == nil || ([self.widget.item stateAsFloat] - [self.widget.step floatValue] >= [self.widget.minValue floatValue])) {
                float setp = [self.widget.item stateAsFloat] - [self.widget.step floatValue];
                [self.widget sendCommand:[NSString stringWithFormat:@"%.01f", setp]];
                //update our local value and UI until we get an update from the server
                [self.widget.item setState: [NSString stringWithFormat:@"%.01f", setp]];
                [self displayWidget];
            }
        }
    // + pressed
    } else if ([segmentedControl selectedSegmentIndex] == 2) {
        if ([self.widget.item.state isEqual:@"Uninitialized"]) {
            [self.widget sendCommand:self.widget.minValue];
        } else {
            if (self.widget.maxValue == nil ||
                ([self.widget.item stateAsFloat] + [self.widget.step floatValue] <= [self.widget.maxValue floatValue])) {
                float setp = [self.widget.item stateAsFloat] + [self.widget.step floatValue];
                [self.widget sendCommand:[NSString stringWithFormat:@"%.01f", setp]];
                //update our local value and UI until we get an update from the server
                [self.widget.item setState: [NSString stringWithFormat:@"%.01f", setp]];
                [self displayWidget];
            }
        }
    }
}

@end
