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

extension OpenHABSitemap {
    convenience init(_ sitemap: Components.Schemas.SitemapDTO) {
        self.init(
            name: sitemap.name.orEmpty,
            icon: sitemap.icon.orEmpty,
            label: sitemap.label.orEmpty,
            link: sitemap.link.orEmpty,
            page: OpenHABPage(sitemap.homepage)
        )
    }
}
