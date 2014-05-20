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
    [[SDImageCache sharedImageCache] removeImageForKey:self.widget.url fromDisk:YES];
}

- (void)displayWidget
{
    widgetImage = (UIImageView*)[self viewWithTag:901];
    [widgetImage setImageWithURL:[NSURL URLWithString:self.widget.url] placeholderImage:nil options:SDWebImageCacheMemoryOnly completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
//        NSLog(@"Image load complete %f %f", self.widgetImage.image.size.width, self.widgetImage.image.size.height);
        if (widget.image == nil) {
            widget.image = self.widgetImage.image;
            [widgetImage setFrame:self.contentView.frame];
            if (self.delegate != nil) {
                [self.delegate didLoadImage];
            }
        }
    }];
}


@end
