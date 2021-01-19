// Copyright (c) 2010-2021 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import Fuzi

// The OpenHAB REST API returns either a value (eg. String, Int, Double...) or false (not null).
// Inspired by https://stackoverflow.com/questions/52836448/decodable-value-string-or-bool
public struct ValueOrFalse<T: Decodable>: Decodable {
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

public final class OpenHABSitemap: NSObject {
    public var name = ""
    public var icon = ""
    public var label = ""
    public var link = ""
    public var leaf: Bool?
    public var homepageLink = ""

    public init(name: String, icon: String, label: String, link: String, leaf: Bool, homepageLink: String) {
        self.name = name
        self.icon = icon
        self.label = label
        self.link = link
        self.leaf = leaf
        self.homepageLink = homepageLink
    }

    public init(xml xmlElement: XMLElement) {
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

public extension OpenHABSitemap {
    struct CodingData: Decodable {
        public let name: String
        public let label: String
        public let page: HomePage
        public let link: String
        public let icon: String?

        private enum CodingKeys: String, CodingKey {
            case page = "homepage"
            case name
            case label
            case link
            case icon
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            name = try container.decode(forKey: .name)
            label = try container.decode(forKey: .label, default: name)
            page = try container.decode(forKey: .page)
            link = try container.decode(forKey: .link)
            icon = try container.decodeIfPresent(forKey: .icon)
        }
    }

    internal enum PageType: Decodable {
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
        public let link: String
        public let leaf: Bool
        public let timeout: ValueOrFalse<String>?
        public let widgets: [OpenHABWidget.CodingData]?
    }
}

public extension OpenHABSitemap.CodingData {
    var openHABSitemap: OpenHABSitemap {
        OpenHABSitemap(
            name: name,
            icon: icon.orEmpty,
            label: label,
            link: link,
            leaf: page.leaf,
            homepageLink: page.link
        )
    }
}
