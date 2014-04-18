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
@synthesize widgetImage;

- (void)loadWidget:(OpenHABWidget *)widgetToLoad
{
    self.widget = widgetToLoad;
}

- (void)displayWidget
{
    widgetImage = (UIImageView*)[self viewWithTag:901];
    [widgetImage setImageWithURL:[NSURL URLWithString:self.widget.url] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
        NSLog(@"Image load complete %f %f", self.widgetImage.image.size.width, self.widgetImage.image.size.height);
        [widgetImage setFrame:self.contentView.frame];
    }];
}


@end
