//
//  SegmentedUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"

@interface SegmentedUITableViewCell : GenericUITableViewCell
{
    UISegmentedControl *widgetSegmentedControl;
}

@property (nonatomic, retain) UISegmentedControl *widgetSegmentedControl;

@end
