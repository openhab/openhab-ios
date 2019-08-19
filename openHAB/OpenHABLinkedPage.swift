//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABLinkedPage.swift
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import Foundation
import Fuzi

@objcMembers class OpenHABLinkedPage: NSObject, Decodable {
    var pageId = ""
    var title = ""
    var icon = ""
    var link = ""

    private enum CodingKeys: String, CodingKey {
        case pageId = "id"
        case title
        case icon
        case link
    }

    init(xml xmlElement: GDataXMLElement?) {
        let propertyNames: Set = ["title", "icon", "link"]
        super.init()
        for child in (xmlElement?.children())! {
            if let child = child as? GDataXMLElement {
                if !(child.name() == "id") {
                    if let name = child.name() {
                        if propertyNames.contains(name) {
                            setValue(child.stringValue(), forKey: child.name() ?? "")
                        }
                    }
                } else {
                    pageId = child.stringValue() ?? ""
                }
            }
        }
    }

    init(xml xmlElement: XMLElement) {
        super.init()
        for child in xmlElement.children {
            switch child.tag {
            case "title": self.title = child.stringValue
            case "icon": self.icon = child.stringValue
            case "link": self.link = child.stringValue
            case "id": self.pageId = child.stringValue
            default:
                break
            }
        }
    }
}
