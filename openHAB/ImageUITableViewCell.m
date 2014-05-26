//
//  ImageUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "ImageUITableViewCell.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDWebImageDownloader.h>

@implementation ImageUITableViewCell
@synthesize widgetImage, delegate;

- (void)loadWidget:(OpenHABWidget *)widgetToLoad
{
    self.widget = widgetToLoad;
    // Remove image from SDImage cache
}

- (void)displayWidget
{
    widgetImage = (UIImageView*)[self viewWithTag:901];
    if (widget.image == nil) {
        int random = arc4random() % 1000;
        [widgetImage setImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@&random=%d", self.widget.url, random]] placeholderImage:nil options:SDWebImageCacheMemoryOnly completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
        widget.image = self.widgetImage.image;
        [widgetImage setFrame:self.contentView.frame];
        if (self.delegate != nil) {
            [self.delegate didLoadImage];
        }
        }];
    } else {
        [widgetImage setImage:widget.image];
    }
}


@end
