//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABAppDataDelegate.swift
//  openHAB
//
//  Created by Victor Belov on 14/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import Foundation

protocol OpenHABAppDataDelegate: NSObjectProtocol {
    func appData() -> OpenHABDataObject?
}