//
//  ColorPickerUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"
#import "UICircleButton.h"
#import "OpenHABItem.h"

@class ColorPickerUITableViewCell;

@protocol ColorPickerUITableViewCellDelegate <NSObject>
- (void) didPressColorButton:(ColorPickerUITableViewCell *) cell;
@end

@interface ColorPickerUITableViewCell : GenericUITableViewCell

@property (nonatomic, retain) UICircleButton *upButton;
@property (nonatomic, retain) UICircleButton *colorButton;
@property (nonatomic, retain) UICircleButton *downButton;
@property (nonatomic, retain) id <ColorPickerUITableViewCellDelegate> delegate;

@end
