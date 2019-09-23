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
import Fuzi

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

final class OpenHABSitemap: NSObject {
    var name = ""
    var icon = ""
    var label = ""
    var link = ""
    var leaf: Bool?
    var homepageLink = ""

    init(name: String, icon: String, label: String, link: String, leaf: Bool, homepageLink: String) {
        self.name = name
        self.icon = icon
        self.label = label
        self.link = link
        self.leaf = leaf
        self.homepageLink = homepageLink
    }

    init(xml xmlElement: XMLElement) {
        super.init()
        for child in xmlElement.children {
            switch child.tag {
            case "name": name = child.stringValue
            case "icon": icon = child.stringValue
            case "label": label = child.stringValue
            case "link": link = child.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            case "leaf": leaf = child.stringValue == "true" ? true : false
            case "homepage":
                for child2 in child.children {
                    switch child2.tag {
                    case "link": homepageLink = child2.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    case "leaf": leaf = child2.stringValue == "true" ? true : false
                    default: break
                    }
                }
            default: break
            }
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
        let timeout: ValueOrFalse<String>?
        let widgets: [OpenHABWidget.CodingData]?
    }
}

extension OpenHABSitemap.CodingData {
    var openHABSitemap: OpenHABSitemap {
        return OpenHABSitemap(name: name,
                              icon: icon ?? "",
                              label: label,
                              link: link,
                              leaf: page.leaf,
                              homepageLink: page.link)
    }
}
