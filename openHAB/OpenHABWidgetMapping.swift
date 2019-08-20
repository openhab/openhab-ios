//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABWidgetMapping.swift
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import Foundation
import Fuzi

@objcMembers class OpenHABWidgetMapping: NSObject, Decodable {
    var command = ""
    var label = ""

    init(xml xmlElement: XMLElement) {
        super.init()
        for child in xmlElement.children {
            switch child.tag {
            case "command": self.command = child.stringValue
            case "label": self.label = child.stringValue
            default:
                break
            }
        }
    }
}
