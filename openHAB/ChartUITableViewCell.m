//
//  ChartUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "ChartUITableViewCell.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDWebImageDownloader.h>
#import "OpenHABItem.h"

@implementation ChartUITableViewCell

- (void)displayWidget
{
    self.widgetImage = (UIImageView*)[self viewWithTag:801];
    NSString *chartUrl;
    int random = arc4random() % 1000;
    if ([self.widget.item.type isEqualToString:@"GroupItem"]) {
        chartUrl = [NSString stringWithFormat:@"%@/chart?groups=%@&period=%@&random=%d", self.baseUrl, self.widget.item.name, self.widget.period, random];
    } else {
        chartUrl = [NSString stringWithFormat:@"%@/chart?items=%@&period=%@&random=%d", self.baseUrl, self.widget.item.name, self.widget.period, random];
    }
    if (self.widget.service != nil && [self.widget.service length] > 0) {
        chartUrl = [NSString stringWithFormat:@"%@&service=%@", chartUrl, self.widget.service];
    }
    NSLog(@"Chart url %@", chartUrl);
    if (widget.image == nil) {
        [self.widgetImage setImageWithURL:[NSURL URLWithString:chartUrl] placeholderImage:nil options:SDWebImageCacheMemoryOnly completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
//        NSLog(@"Image load complete %f %f", self.widgetImage.image.size.width, self.widgetImage.image.size.height);
            widget.image = self.widgetImage.image;
            [self.widgetImage setFrame:self.contentView.frame];
            if (self.delegate != nil) {
                [self.delegate didLoadImage];
            }
        }];
    } else {
        [self.widgetImage setImage:widget.image];
    }
}


@end
