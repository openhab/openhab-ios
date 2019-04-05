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
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import Foundation

// The OpenHAB REST API returns either a value (eg. String, Int, Double...) or false (not null).
// Inspired by https://stackoverflow.com/questions/52836448/decodable-value-string-or-bool
struct ValueOrFalse<T: Decodable>: Decodable {
    let value: T?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let falseValue = try? container.decode(Bool.self)
        if falseValue == nil {
            value = try container.decode(T.self)
        } else {
            value = nil
        }
    }
}

extension OpenHABSitemap {

    struct CodingData: Decodable {
        let name: String
        let label: String
        let homepage: HomePage
        let link: String
    }

    struct HomePage: Decodable {
        let link: String
        let leaf: Bool
        let timeout: ValueOrFalse<String>
    }
}

extension OpenHABSitemap.CodingData {
    var openHABSitemap: OpenHABSitemap {
        return OpenHABSitemap(name: self.name, link: self.link, label: self.label, leaf: self.homepage.leaf, homepageLink: self.homepage.link)
    }
}

@objcMembers final class OpenHABSitemap: NSObject {
    var name = ""
    var icon = ""
    var label = ""
    var link = ""
    var leaf = ""
    var homepageLink = ""

    init(name: String, link: String, label: String, leaf: Bool, homepageLink: String) {
        self.name = name
        self.link = link
        self.label = label
        self.leaf = leaf ? "true" : "false"
        self.homepageLink = homepageLink
    }

    init(xml xmlElement: GDataXMLElement?) {
        let propertyNames: Set = ["name", "icon", "label", "link", "leaf"]
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
                        setValue(child.stringValue, forKey: child.name() )
                    }
                }
            }
        }
    }
}
