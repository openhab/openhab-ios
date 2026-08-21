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

@testable import openHAB
import OpenHABCore
import Testing

@Suite("MenuDataService")
@MainActor
struct MenuDataTests {
    // MARK: - Sitemap filtering

    @Test("Filters out _default sitemap when others exist")
    func filtersDefaultSitemap() {
        let sitemaps = [
            makeSitemap(name: "home", label: "Home"),
            makeSitemap(name: "garden", label: "Garden"),
            makeSitemap(name: "_default", label: "Default")
        ]
        let result = MenuDataService.filterAndSortSitemaps(sitemaps, sortBy: .name)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.name != "_default" })
    }

    @Test("Keeps _default when it is the only sitemap")
    func keepsDefaultWhenAlone() {
        let sitemaps = [
            makeSitemap(name: "_default", label: "Default")
        ]
        let result = MenuDataService.filterAndSortSitemaps(sitemaps, sortBy: .name)
        #expect(result.count == 1)
        #expect(result[0].name == "_default")
    }

    @Test("Does not filter _default if it is not the last element")
    func defaultNotLastIsKept() {
        let sitemaps = [
            makeSitemap(name: "_default", label: "Default"),
            makeSitemap(name: "home", label: "Home")
        ]
        let result = MenuDataService.filterAndSortSitemaps(sitemaps, sortBy: .name)
        // _default is not last, so it stays
        #expect(result.count == 2)
    }

    // MARK: - Sitemap sorting

    @Test("Sorts sitemaps by label")
    func sortsByLabel() {
        let sitemaps = [
            makeSitemap(name: "z_name", label: "Zebra"),
            makeSitemap(name: "a_name", label: "Alpha"),
            makeSitemap(name: "m_name", label: "Middle")
        ]
        let result = MenuDataService.filterAndSortSitemaps(sitemaps, sortBy: .label)
        #expect(result.map(\.label) == ["Alpha", "Middle", "Zebra"])
    }

    @Test("Sorts sitemaps by name")
    func sortsByName() {
        let sitemaps = [
            makeSitemap(name: "z_name", label: "Zebra"),
            makeSitemap(name: "a_name", label: "Alpha"),
            makeSitemap(name: "m_name", label: "Middle")
        ]
        let result = MenuDataService.filterAndSortSitemaps(sitemaps, sortBy: .name)
        #expect(result.map(\.name) == ["a_name", "m_name", "z_name"])
    }

    @Test("Empty sitemaps returns empty")
    func emptySitemaps() {
        let result = MenuDataService.filterAndSortSitemaps([], sortBy: .label)
        #expect(result.isEmpty)
    }

    // MARK: - Helpers

    private func makeSitemap(name: String, label: String) -> OpenHABSitemap {
        OpenHABSitemap(name: name, icon: "", label: label, link: "", page: nil)
    }
}
