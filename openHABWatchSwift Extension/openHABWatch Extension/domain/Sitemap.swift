//
//  Sitemap.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

struct Sitemap {
    let frames: [Frame]

    init(frames: [Frame]) {
        self.frames = frames
    }
}

extension Sitemap {
    init? (with codingData: OpenHABSitemap.CodingData?) {
        let frame = Frame(with: codingData)!
        self.init(frames: [frame])
    }
}
