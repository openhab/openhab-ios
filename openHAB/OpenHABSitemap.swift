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
import os.log

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

func deriveSitemaps(_ response: Data?, version: Int?) -> [OpenHABSitemap] {
    guard let response = response else {
        return []
    }

    if version == 1 {
        // If we are talking to openHAB 1.X, talk XML
        os_log("openHAB 1", log: .viewCycle, type: .info)

        os_log("%{PUBLIC}@", log: .remoteAccess, type: .info, String(data: response, encoding: .utf8) ?? "")

        guard let doc = try? GDataXMLDocument(data: response) else {
            return []
        }

        if let name = doc.rootElement().name() {
            os_log("%{PUBLIC}@", log: .remoteAccess, type: .info, name)
        }

        guard doc.rootElement().name() == "sitemaps" else {
            return []
        }

        return doc.rootElement().elements(forName: "sitemap")
            .compactMap { $0 as? GDataXMLElement }
            .map { OpenHABSitemap(xml: $0) }
            .sorted { $0.name < $1.name }
    } else {
        // Newer versions speak JSON!
        os_log("openHAB 2", log: .viewCycle, type: .info)

        do {
            return (try response.decoded() as [OpenHABSitemap.CodingData])
                .map { $0.openHABSitemap }
                .sorted { $0.name < $1.name }
        } catch {
            os_log("Failed parsing sitemaps from JSON: %{public}@", log: .notifications, type: .error, error.localizedDescription)
            return []
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
        return OpenHABSitemap(
            name: self.name,
            icon: self.icon ?? "",
            label: self.label,
            link: self.link,
            leaf: self.page.leaf,
            homepageLink: self.page.link
        )
    }
}

@objcMembers final class OpenHABSitemap: NSObject {
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
                                leaf = childChild.stringValue() == "true"
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
