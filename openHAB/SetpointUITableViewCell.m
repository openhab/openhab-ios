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

@interface SetpointUITableViewCell()

@property (nonatomic, readonly) BOOL isIntStep;
@property (nonatomic, readonly) NSString *stateFormat;

@end

@implementation SetpointUITableViewCell

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
        if (!self.isIntStep){
            widgetValue = [NSString stringWithFormat:self.stateFormat, [self.widget.item stateAsFloat]];
        } else {
            widgetValue = [NSString stringWithFormat:self.stateFormat, [self.widget.item stateAsInt]];
        }
    }
    [self.widgetSegmentedControl setTitle:widgetValue forSegmentAtIndex:1];
    [self.widgetSegmentedControl addTarget:self
                         action:@selector(pickOne:)
               forControlEvents:UIControlEventValueChanged];
}

- (void)decreaseValue {
    if ([self.widget.item.state isEqual:@"Uninitialized"]) {
        [self.widget sendCommand:(NSString*)self.widget.minValue];
    } else {
        if (self.widget.minValue != nil) {
            if (!self.isIntStep) {
                float newValue = [self.widget.item stateAsFloat] - [self.widget.step floatValue];
                if (newValue >= [self.widget.minValue floatValue]) {
                    [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, newValue]];
                } else {
                    [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, [self.widget.minValue floatValue]]];
                }
            } else {
                NSInteger newValue = [self.widget.item stateAsInt] - [self.widget.step integerValue];
                if (newValue >= [self.widget.minValue integerValue]) {
                    [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, newValue]];
                } else {
                    [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, [self.widget.minValue integerValue]]];
                }
            }
        } else {
            if (!self.isIntStep) {
                [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, [self.widget.item stateAsFloat] - [self.widget.step floatValue]]];
            }
            else {
                [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, [self.widget.item stateAsInt] - [self.widget.step integerValue]]];
            }
        }
    }
}

- (void)increaseValue {
    if ([self.widget.item.state isEqual:@"Uninitialized"]) {
        [self.widget sendCommand:(NSString*)self.widget.minValue];
    } else {
        if (self.widget.maxValue != nil) {
            if (!self.isIntStep) {
                float newValue = [self.widget.item stateAsFloat] + [self.widget.step floatValue];
                if (newValue <= [self.widget.maxValue floatValue]) {
                    [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, newValue]];
                } else {
                    [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, [self.widget.maxValue floatValue]]];
                }
            } else {
                NSInteger newValue = [self.widget.item stateAsInt] + [self.widget.step integerValue];
                if (newValue <= [self.widget.maxValue integerValue]) {
                    [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, newValue]];
                } else {
                    [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, [self.widget.maxValue integerValue]]];
                }
            }
        } else {
            if (!self.isIntStep) {
                [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, [self.widget.item stateAsFloat] + [self.widget.step floatValue]]];
            }
            else {
                [self.widget sendCommand:[NSString stringWithFormat:self.stateFormat, [self.widget.item stateAsInt] + [self.widget.step integerValue]]];
            }
        }
    }
}

-(void) pickOne:(id)sender
{
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    NSLog(@"Setpoint pressed %ld", [segmentedControl selectedSegmentIndex]);
    // Deselect segment in the middle
    if ([segmentedControl selectedSegmentIndex] == 1) {
        [self.widgetSegmentedControl setSelectedSegmentIndex:-1];
    // - pressed
    } else if ([segmentedControl selectedSegmentIndex] == 0) {
        [self decreaseValue];
    // + pressed
    } else if ([segmentedControl selectedSegmentIndex] == 2) {
        [self increaseValue];
    }
}

- (NSString *)stateFormat
{
    return self.isIntStep ? @"%ld" : @"%.01f";
}

- (BOOL)isIntStep
{
    return [self.widget.step floatValue] == [self.widget.step integerValue];
}

@end
