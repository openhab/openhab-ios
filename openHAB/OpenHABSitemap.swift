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
        let page: HomePage
        let link: String
        let icon: String?

        private enum CodingKeys: String, CodingKey {
            case page = "homepage"
            case name
            case label
            case link
            case icon
        }
    }

    enum PageType: Decodable {
        case homepage(HomePage)
        case linkedPage(HomePage)

        private enum CodingKeys: String, CodingKey {
            case homepage
            case linkedPage
        }

        enum PostTypeCodingError: Error {
            case decoding(String)
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let homePageValue = try? container.decode(HomePage.self, forKey: .homepage) {
                self = .homepage(homePageValue)
                return
            }
            if let linkedPageValue = try? container.decode(HomePage.self, forKey: .linkedPage) {
                self = .linkedPage(linkedPageValue)
                return
            }
            throw PostTypeCodingError.decoding("Whoops! \(dump(container))")
        }
    }

    struct HomePage: Decodable {
        let link: String
        let leaf: Bool
        let timeout: ValueOrFalse<String>
        let widgets: [OpenHABWidget.CodingData]?
    }
}

extension OpenHABSitemap.CodingData {
    var openHABSitemap: OpenHABSitemap {
        return OpenHABSitemap(name: self.name, link: self.link, label: self.label, leaf: self.page.leaf, homepageLink: self.page.link, icon: self.icon ?? "")
    }
}

@objcMembers final class OpenHABSitemap: NSObject {
    var name = ""
    var icon = ""
    var label = ""
    var link = ""
    var leaf = ""
    var homepageLink = ""

    init(name: String, link: String, label: String, leaf: Bool, homepageLink: String, icon: String) {
        self.name = name
        self.icon = icon
        self.link = link
        self.label = label
        self.leaf = leaf ? "true" : "false"
        self.homepageLink = homepageLink
    }

#if canImport(GDataXMLElement)
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
#endif
}
