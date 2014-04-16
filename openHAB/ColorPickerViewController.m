//
//  ColorPickerViewController.m
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "ColorPickerViewController.h"
#import "NKOColorPickerView.h"
#import "OpenHABItem.h"

@interface ColorPickerViewController ()

@end

@implementation ColorPickerViewController
@synthesize widget;

- (id)initWithCoder:(NSCoder *)coder
{
    NSLog(@"ColorPickerViewController initWithCoder");
    self = [super initWithCoder:coder];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad
{
    NSLog(@"ColorPickerViewController viewDidLoad");
    NKOColorPickerDidChangeColorBlock colorDidChangeBlock = ^(UIColor *color){
        CGFloat hue;
        CGFloat saturation;
        CGFloat brightness;
        CGFloat alpha;
        [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
        hue = hue*360;
        saturation = saturation*100;
        brightness = brightness*100;
        NSLog(@"Color changed to %f %f %f", hue, saturation, brightness);
        NSString *command = [NSString stringWithFormat:@"%f,%f,%f", hue, saturation, brightness];
        [self.widget sendCommand:command];
    };
    CGRect viewFrame = self.view.frame;
    CGRect pickerFrame = CGRectMake(viewFrame.origin.x, viewFrame.origin.y + viewFrame.size.height/20, viewFrame.size.width, viewFrame.size.height - viewFrame.size.height/5);
    NKOColorPickerView *colorPickerView = [[NKOColorPickerView alloc] initWithFrame:pickerFrame color:[UIColor blueColor] andDidChangeColorBlock:colorDidChangeBlock];
    [self.view addSubview:colorPickerView];
    if (self.widget != nil) {
        [colorPickerView setColor:[self.widget.item stateAsUIColor]];
    }
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
