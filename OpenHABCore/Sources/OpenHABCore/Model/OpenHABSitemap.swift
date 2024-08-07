// Copyright (c) 2010-2024 Contributors to the openHAB project
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
    public var page: OpenHABPage?

    public var leaf: Bool? {
        page?.leaf
    }

    public var homepageLink: String {
        page?.link ?? ""
    }

    public init(name: String, icon: String, label: String, link: String, page: OpenHABPage?) {
        self.name = name
        self.icon = icon
        self.label = label
        self.link = link
        self.page = page
    }
}

public extension OpenHABSitemap {
    struct CodingData: Decodable {
        public let name: String
        public let label: String
        public let page: OpenHABPage.CodingData?
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
}

public extension OpenHABSitemap.CodingData {
    var openHABSitemap: OpenHABSitemap {
        OpenHABSitemap(
            name: name,
            icon: icon.orEmpty,
            label: label,
            link: link,
            page: page?.openHABSitemapPage
        )
    }
}
