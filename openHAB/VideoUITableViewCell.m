//
//  VideoUITableViewCell.m
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "VideoUITableViewCell.h"

@implementation VideoUITableViewCell
@synthesize videoPlayer;

- (void)loadWidget:(OpenHABWidget *)widgetToLoad
{
    self.widget = widgetToLoad;
}

- (void)displayWidget
{
    NSLog(@"Video url = %@", widget.url);
//    videoPlayer = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:widget.url]];
//    videoPlayer.view.frame = self.contentView.bounds;
//    [self.contentView addSubview:videoPlayer.view];
//    [videoPlayer prepareToPlay];
//    [videoPlayer play];
}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
//    [videoPlayer.view setFrame:frame];
}

@end
