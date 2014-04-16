//
//  SliderUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"

@interface SliderUITableViewCell : GenericUITableViewCell
{
    UISlider *widgetSlider;
}

@property (nonatomic, retain) UISlider *widgetSlider;

@end
