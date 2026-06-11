// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

/// Navigation value pushed onto a platform NavigationStack when a linked-page widget is tapped.
///
/// Shared across iOS and watchOS so both platforms use the same navigation contract.
public struct SitemapLinkedPage: Hashable, Sendable {
    /// Full REST URL of the sitemap page (e.g. `https://server/rest/sitemaps/home/ground`).
    public let link: String
    /// Human-readable page title shown in the navigation bar.
    public let title: String
    /// Page identifier used when polling (`SitemapPageLoader.stream(sitemapName:pageId:…)`).
    public let pageId: String

    public init(link: String, title: String, pageId: String) {
        self.link = link
        self.title = title
        self.pageId = pageId
    }
}
