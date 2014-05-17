//
//  ImageUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"

@class ImageUITableViewCell;

@protocol ImageUITableViewCellDelegate <NSObject>
- (void)didLoadImage;
@end

@interface ImageUITableViewCell : GenericUITableViewCell

@property (nonatomic, retain) UIImageView *widgetImage;
@property (nonatomic, retain) id <ImageUITableViewCellDelegate> delegate;

@end
