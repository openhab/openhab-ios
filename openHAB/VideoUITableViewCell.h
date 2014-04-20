//
//  VideoUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"
#import <MediaPlayer/MediaPlayer.h>

@interface VideoUITableViewCell : GenericUITableViewCell

@property (nonatomic, retain) MPMoviePlayerController *videoPlayer;

@end
