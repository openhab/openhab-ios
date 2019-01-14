//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABSitemap.swift
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

//
//  OpenHABSitemap.swift
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  This class parses and holds data for a sitemap list entry
//  REST: /sitemaps
//

import Foundation

@objcMembers class OpenHABSitemap: NSObject {
    var name = ""
    var icon = ""
    var label = ""
    var link = ""
    var leaf = ""
    var homepageLink = ""

    let propertyNames: Set = ["name", "icon", "label", "link", "leaf"]

    init(xml xmlElement: GDataXMLElement?) {
        super.init()
        for child in (xmlElement?.children())! {
            if let child = child as? GDataXMLElement {
                if child.name() == "homepage" {
                    for childChild in (child.children())! {
                        if let childChild = childChild as? GDataXMLElement {
                        if childChild.name() == "link" {
                            homepageLink = childChild.stringValue() ?? ""
                        }
                        if childChild.name() == "leaf" {
                            leaf = childChild.stringValue() ?? ""
                        }
                    }
                }
                } else if let name = child.name() {
                    if propertyNames.contains(name) {
                        setValue(child.stringValue ?? "", forKey: child.name() ?? "")
                }
            }
        }
    }
}

init(dictionary: [String : Any]) {
    super.init()
    let keyArray = dictionary.keys
    for key in keyArray  {
        if (key == "homepage") {
            let homepageDictionary = dictionary[key] as? [String : Any]
            let homepageKeyArray = homepageDictionary!.keys
            for homepageKey in homepageKeyArray {
                if (homepageKey == "link") {
                    homepageLink = homepageDictionary?[homepageKey] as? String ?? ""
                }
                if (homepageKey == "leaf") {
                    leaf = homepageDictionary?[homepageKey] as? String ?? ""
                }
            }
        } else if propertyNames.contains(key) {
            setValue(dictionary[key], forKey: key ?? "")
        }
    }
}
}
