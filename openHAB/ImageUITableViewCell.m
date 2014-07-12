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

NSTimer *refreshTimer;

- (void)loadWidget:(OpenHABWidget *)widgetToLoad
{
    self.widget = widgetToLoad;
    // Remove image from SDImage cache
}

- (void)displayWidget
{
    widgetImage = (UIImageView*)[self viewWithTag:901];
    if (widget.image == nil) {
        [self loadImage];
    } else {
        [widgetImage setImage:widget.image];
    }
    // If widget have a refresh rate configured, schedule an image update timer
    if (self.widget.refresh != nil && refreshTimer == nil) {
        NSTimeInterval refreshInterval = [self.widget.refresh floatValue] / 1000;
        refreshTimer = [NSTimer scheduledTimerWithTimeInterval:refreshInterval
                                                        target:self
                                                      selector:@selector(refreshImage:)
                                                      userInfo:nil
                                                       repeats:YES];
    }
}

- (void)loadImage
{
    int random = arc4random() % 1000;
    [widgetImage setImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@&random=%d", self.widget.url, random]] placeholderImage:nil options:SDWebImageCacheMemoryOnly completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
        widget.image = self.widgetImage.image;
        [widgetImage setFrame:self.contentView.frame];
        if (self.delegate != nil) {
            [self.delegate didLoadImage];
        }
    }];
}

- (void)refreshImage:(NSTimer *)timer
{
    int random = arc4random() % 1000;
    [widgetImage setImageWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@&random=%d", self.widget.url, random]] placeholderImage:self.widgetImage.image options:SDWebImageCacheMemoryOnly completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
        widget.image = self.widgetImage.image;
    }];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    if (newWindow == nil && refreshTimer != nil) {
        [refreshTimer invalidate];
        refreshTimer = nil;
    }
}

@end
