//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  VideoUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import MediaPlayer

class VideoUITableViewCell: GenericUITableViewCell {
    var videoPlayer: MPMoviePlayerController?

    override func displayWidget() {
        print("Video url = \(widget.url)")
        //    videoPlayer = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:widget.url]];
        //    videoPlayer.view.frame = self.contentView.bounds;
        //    [self.contentView addSubview:videoPlayer.view];
        //    [videoPlayer prepareToPlay];
        //    [videoPlayer play];
    }

    func setFrame(_ frame: CGRect) {
        super.frame = frame
        //    [videoPlayer.view setFrame:frame];
    }
}
