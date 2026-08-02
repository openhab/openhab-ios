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

import Foundation
@testable import OpenHABCore
import Testing

struct SitemapDisplayTests {
    private func makeSitemap(name: String, label: String) -> OpenHABSitemap {
        OpenHABSitemap(name: name, icon: "", label: label, link: "", page: nil)
    }

    // MARK: - SortSitemapsOrder primary/secondary

    @Test
    func sortOrderPicksPrimaryField() {
        let sitemap = makeSitemap(name: "watch", label: "Home")
        #expect(SortSitemapsOrder.label.primaryText(for: sitemap) == "Home")
        #expect(SortSitemapsOrder.label.secondaryText(for: sitemap) == "watch")
        #expect(SortSitemapsOrder.name.primaryText(for: sitemap) == "watch")
        #expect(SortSitemapsOrder.name.secondaryText(for: sitemap) == "Home")
    }

    @Test
    func combinedStringCollapsesEqualValues() {
        #expect(SortSitemapsOrder.combined("Home", "watch") == "Home – watch")
        #expect(SortSitemapsOrder.combined("Home", "Home") == "Home")
    }

    // MARK: - SitemapNameLabelDisplayMode default resolution (upgrade path)

    @Test
    func resolvedMapsMissingValueToLabel() {
        // Missing (pre-setting data / fresh install) must default to `.label` to
        // match the behaviour of the app before this setting existed.
        #expect(SitemapNameLabelDisplayMode.resolved(nil) == .label)
        #expect(SitemapNameLabelDisplayMode.resolved(.name) == .name)
        #expect(SitemapNameLabelDisplayMode.resolved(.both) == .both)
    }

    // MARK: - SitemapNameLabelDisplayMode title/detail

    @Test
    func nameModeShowsOnlyName() {
        let sitemap = makeSitemap(name: "watch", label: "Home")
        for order in SortSitemapsOrder.allCases {
            #expect(SitemapNameLabelDisplayMode.name.titleText(for: sitemap, sortedBy: order) == "watch")
            #expect(SitemapNameLabelDisplayMode.name.detailText(for: sitemap, sortedBy: order) == "")
        }
    }

    @Test
    func labelModeShowsOnlyLabel() {
        let sitemap = makeSitemap(name: "watch", label: "Home")
        for order in SortSitemapsOrder.allCases {
            #expect(SitemapNameLabelDisplayMode.label.titleText(for: sitemap, sortedBy: order) == "Home")
            #expect(SitemapNameLabelDisplayMode.label.detailText(for: sitemap, sortedBy: order) == "")
        }
    }

    @Test
    func bothModeFollowsSortOrderForTitle() {
        let sitemap = makeSitemap(name: "watch", label: "Home")
        #expect(SitemapNameLabelDisplayMode.both.titleText(for: sitemap, sortedBy: .label) == "Home")
        #expect(SitemapNameLabelDisplayMode.both.detailText(for: sitemap, sortedBy: .label) == "watch")
        #expect(SitemapNameLabelDisplayMode.both.titleText(for: sitemap, sortedBy: .name) == "watch")
        #expect(SitemapNameLabelDisplayMode.both.detailText(for: sitemap, sortedBy: .name) == "Home")
    }

    @Test
    func bothModeCollapsesDetailWhenNameEqualsLabel() {
        let sitemap = makeSitemap(name: "Home", label: "Home")
        #expect(SitemapNameLabelDisplayMode.both.titleText(for: sitemap, sortedBy: .label) == "Home")
        #expect(SitemapNameLabelDisplayMode.both.detailText(for: sitemap, sortedBy: .label) == "")
    }

    // MARK: - SitemapNameLabelDisplayMode combined (picker) form

    @Test
    func combinedTextForPickers() {
        let sitemap = makeSitemap(name: "watch", label: "Home")
        #expect(SitemapNameLabelDisplayMode.name.combinedText(for: sitemap, sortedBy: .label) == "watch")
        #expect(SitemapNameLabelDisplayMode.label.combinedText(for: sitemap, sortedBy: .name) == "Home")
        #expect(SitemapNameLabelDisplayMode.both.combinedText(for: sitemap, sortedBy: .label) == "Home – watch")
        #expect(SitemapNameLabelDisplayMode.both.combinedText(for: sitemap, sortedBy: .name) == "watch – Home")

        let ambiguous = makeSitemap(name: "Home", label: "Home")
        #expect(SitemapNameLabelDisplayMode.both.combinedText(for: ambiguous, sortedBy: .name) == "Home")
    }
}
