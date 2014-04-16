//
//  RollershutterUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 27/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"

@interface RollershutterUITableViewCell : GenericUITableViewCell

@property (nonatomic, retain) UIButton * downButton;
@property (nonatomic, retain) UIButton * stopButton;
@property (nonatomic, retain) UIButton * upButton;

@end
