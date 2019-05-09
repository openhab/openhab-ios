//
//  Sitemap.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

/** OpenHab Sitemap containing a list of frames **/
class Sitemap : NSObject, NSCoding {
    
    let frames : [Frame]
    
    init(frames : [Frame]) {
        self.frames = frames
    }
    
    // serializer
    required init(coder decoder: NSCoder) {
        self.frames = decoder.decodeObject(forKey: "frames") as! [Frame]
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(frames, forKey: "frames")
    }
}
