//
//  SetpointUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 16/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"

@interface SetpointUITableViewCell : GenericUITableViewCell
{
    UISegmentedControl *widgetSegmentedControl;
}

@property (nonatomic, retain) UISegmentedControl *widgetSegmentedControl;
@property (nonatomic, retain) UILabel *textLabel;


@end
