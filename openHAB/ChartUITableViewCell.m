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
@synthesize chartImage;

- (void)displayWidget
{
    chartImage = (UIImageView*)[self viewWithTag:801];
    NSString *chartUrl;
    int random = arc4random() % 1000;
    if ([self.widget.item.type isEqualToString:@"GroupItem"]) {
        chartUrl = [NSString stringWithFormat:@"%@/chart?groups=%@&period=%@&random=%d", self.baseUrl, self.widget.item.name, self.widget.period, random];
    } else {
        chartUrl = [NSString stringWithFormat:@"%@/chart?item=%@&period=%@&random=%d", self.baseUrl, self.widget.item.name, self.widget.period, random];
    }
    NSLog(@"Chart url %@", chartUrl);
    [chartImage setImageWithURL:[NSURL URLWithString:chartUrl]];
}


@end
