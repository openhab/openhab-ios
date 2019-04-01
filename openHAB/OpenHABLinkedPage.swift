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

@objc class OpenHABLinkedPage: NSObject, Decodable {
    var pageId = ""
    @objc var title = ""
    @objc var icon = ""
    @objc var link = ""

    private enum CodingKeys: String, CodingKey {
        case pageId = "id"
        case title
        case icon
        case link
    }

    @objc init(xml xmlElement: GDataXMLElement?) {
        let propertyNames: Set = ["title", "icon", "link"]
        super.init()
        for child in (xmlElement?.children())! {
            if let child = child as? GDataXMLElement {
                if !(child.name() == "id") {
                    if let name = child.name() {
                        if propertyNames.contains(name) {
                            setValue(child.stringValue, forKey: child.name() ?? "")
                        }
                    }
                } else {
                    pageId = child.stringValue() ?? ""
                }
            }
        }
    }
}
