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

@objc class OpenHABLinkedPage: NSObject {
    var pageId = ""
    @objc var title = ""
    @objc var icon = ""
    @objc var link = ""
    let propertyNames: Set = ["title", "icon", "link"]

    @objc init(xml xmlElement: GDataXMLElement?) {
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

    @objc init(dictionary: [String: Any]) {
        super.init()
        for key in dictionary.keys {
            if key == "id" {
                pageId = dictionary[key] as? String ?? ""
            } else {

                if propertyNames.contains(key) {
                    setValue(dictionary[key], forKey: key)
                }
            }
        }
    }
}
