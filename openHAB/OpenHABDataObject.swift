//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABDataObject.swift
//  openHAB
//
//  Created by Victor Belov on 14/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import Foundation

class OpenHABDataObject: NSObject {
    var openHABRootUrl = ""
    var sitemaps: [OpenHABSitemap] = []
    var openHABUsername = ""
    var openHABPassword = ""
    var rootViewController: OpenHABViewController?
    var openHABVersion: Int = 0
}
