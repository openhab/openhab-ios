//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABWidgetMapping.swift
//  openHAB
//
//  Created by Victor Belov on 17/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import Foundation

@objc class OpenHABWidgetMapping: NSObject {
    @objc var command = ""
    @objc var label = ""

    @objc init(xml xmlElement: GDataXMLElement?) {
        super.init()
        for child in (xmlElement?.children())! {
            if let child = child as? GDataXMLElement {
                if let name = child.name() {
                    if propertyNames.contains(name) {
                        setValue(child.stringValue ?? "", forKey: child.name() ?? "")
                    }
                }
            }
        }
    }

    let propertyNames: Set = ["command", "label"]

    @objc init(dictionary: [String : Any]) {
        super.init()
        for key in dictionary.keys {
//            if allPropertyNames().contains(key ?? "") {
//                setValue(dictionary[key], forKey: key ?? "")
            if propertyNames.contains(key) {
                    setValue(dictionary[key], forKey: key)
            }
        }
    }
}
