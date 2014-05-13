//
//  SegmentedUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "SegmentedUITableViewCell.h"
#import "OpenHABWidget.h"
#import "OpenHABItem.h"
#import "OpenHABWidgetMapping.h"

@implementation SegmentedUITableViewCell
@synthesize widgetSegmentedControl;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.widgetSegmentedControl = (UISegmentedControl *)[self viewWithTag:500];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.separatorInset = UIEdgeInsetsZero;
    }
    return self;
}

- (void)displayWidget
{
    self.textLabel.text = [self.widget labelText];
    widgetSegmentedControl.apportionsSegmentWidthsByContent = YES;
    [self.widgetSegmentedControl removeAllSegments];
    [self.widgetSegmentedControl setApportionsSegmentWidthsByContent:YES];
    for (OpenHABWidgetMapping *mapping in self.widget.mappings) {
        [self.widgetSegmentedControl insertSegmentWithTitle:mapping.label atIndex:[self.widget.mappings indexOfObject:mapping] animated:NO];
    }
    [self.widgetSegmentedControl setSelectedSegmentIndex:[self.widget mappingIndexByCommand:self.widget.item.state]];
    [self.widgetSegmentedControl addTarget:self
                                    action:@selector(pickOne:)
                          forControlEvents:UIControlEventValueChanged];
}

-(void) pickOne:(id)sender
{
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    NSLog(@"Segment pressed %d", [segmentedControl selectedSegmentIndex]);
    if (self.widget.mappings != nil) {
        OpenHABWidgetMapping *mapping = [self.widget.mappings objectAtIndex:[segmentedControl selectedSegmentIndex]];
        [self.widget sendCommand:mapping.command];
    }
}

@end
