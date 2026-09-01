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

    // MARK: - State machine

    @Test("hasSuccessfullyLoaded is false on init")
    func initialLoadGateIsFalse() {
        let service = MenuDataService()
        #expect(service.hasSuccessfullyLoaded == false)
    }

    @Test("clearAll empties all collections")
    func clearAllEmptiesCollections() {
        let service = MenuDataService()
        service.sitemaps = [makeSitemap(name: "a", label: "A")]
        service.uiTiles = [makeUITile()]
        service.uiPages = [makeUIPage()]
        service.clearAll()
        #expect(service.sitemaps.isEmpty)
        #expect(service.uiTiles.isEmpty)
        #expect(service.uiPages.isEmpty)
    }

    @Test("clearAll does not reset hasSuccessfullyLoaded")
    func clearAllKeepsLoadGate() {
        let service = MenuDataService()
        service.hasSuccessfullyLoaded = true
        service.clearAll()
        // clearAll is for refresh, not home switch — gate should stay true
        #expect(service.hasSuccessfullyLoaded == true)
    }

    @Test("clearForHomeSwitch empties collections and resets load gate")
    func clearForHomeSwitchResetsAll() {
        let service = MenuDataService()
        service.sitemaps = [makeSitemap(name: "a", label: "A")]
        service.hasSuccessfullyLoaded = true
        service.clearForHomeSwitch()
        #expect(service.sitemaps.isEmpty)
        #expect(service.uiTiles.isEmpty)
        #expect(service.uiPages.isEmpty)
        #expect(service.hasSuccessfullyLoaded == false)
    }

    // MARK: - Helpers

    private func makeSitemap(name: String, label: String) -> OpenHABSitemap {
        OpenHABSitemap(name: name, icon: "", label: label, link: "", page: nil)
    }

    private func makeUITile() -> OpenHABUiTile {
        OpenHABUiTile(name: "Tile", url: "/ui/tile", imageUrl: "")
    }

    private func makeUIPage() -> OpenHABUIPage {
        OpenHABUIPage(uid: "page1", label: "Page", icon: "", order: 0, url: "/ui/page1")
    }
}

// MARK: - Connection symbol logic

@Suite("InlineHomePickerView.connectionSymbols")
@MainActor
struct ConnectionSymbolTests {
    @Test("Demo mode yields no symbols")
    func demoModeYieldsEmpty() throws {
        let prefs = try makePrefs(demomode: true)
        #expect(InlineHomePickerView.connectionSymbols(for: prefs).isEmpty)
    }

    @Test("No local URL and cloud disabled yields no symbols")
    func noConnectionsYieldsEmpty() throws {
        let prefs = try makePrefs()
        #expect(InlineHomePickerView.connectionSymbols(for: prefs).isEmpty)
    }

    @Test("Local URL configured yields wifi symbol")
    func localURLYieldsWifi() throws {
        let prefs = try makePrefs(localURL: "http://192.168.1.1:8080")
        #expect(InlineHomePickerView.connectionSymbols(for: prefs) == [.wifi])
    }

    @Test("Cloud enabled with username and password yields cloudFill")
    func cloudWithCredentialsYieldsCloudFill() throws {
        let prefs = try makePrefs(remoteUsername: "user@example.com", remotePassword: "secret", cloudEnabled: true)
        #expect(InlineHomePickerView.connectionSymbols(for: prefs) == [.cloudFill])
    }

    @Test("Cloud enabled without username yields cloudSlash")
    func cloudWithoutUsernameYieldsCloudSlash() throws {
        let prefs = try makePrefs(cloudEnabled: true)
        #expect(InlineHomePickerView.connectionSymbols(for: prefs) == [.cloudSlash])
    }

    @Test("Cloud enabled with username but no password yields cloudSlash")
    func cloudWithUsernameButNoPasswordYieldsCloudSlash() throws {
        let prefs = try makePrefs(remoteUsername: "user@example.com", cloudEnabled: true)
        #expect(InlineHomePickerView.connectionSymbols(for: prefs) == [.cloudSlash])
    }

    @Test("Cloud enabled with empty URL yields cloudSlash")
    func cloudWithEmptyURLYieldsCloudSlash() throws {
        let prefs = try makePrefs(remoteURL: "", remoteUsername: "user@example.com", remotePassword: "secret", cloudEnabled: true)
        #expect(InlineHomePickerView.connectionSymbols(for: prefs) == [.cloudSlash])
    }

    @Test("Local URL plus cloud with credentials yields wifi and cloudFill")
    func localAndCloudWithCredentials() throws {
        let prefs = try makePrefs(localURL: "http://192.168.1.1:8080", remoteUsername: "user@example.com", remotePassword: "secret", cloudEnabled: true)
        #expect(InlineHomePickerView.connectionSymbols(for: prefs) == [.wifi, .cloudFill])
    }

    @Test("Local URL plus cloud without credentials yields wifi and cloudSlash")
    func localAndCloudWithoutCredentials() throws {
        let prefs = try makePrefs(localURL: "http://192.168.1.1:8080", cloudEnabled: true)
        #expect(InlineHomePickerView.connectionSymbols(for: prefs) == [.wifi, .cloudSlash])
    }

    // MARK: - Helper

    /// Constructs a `HomePreferences` via JSON decoding, which is the only way to
    /// create one from outside `OpenHABCore` (the memberwise init is fileprivate).
    private func makePrefs(
        demomode: Bool = false,
        localURL: String = "",
        remoteURL: String = "https://myopenhab.org",
        remoteUsername: String = "",
        remotePassword: String = "",
        cloudEnabled: Bool = false
    ) throws -> HomePreferences {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "demomode": \(demomode),
            "localConnectionConfig": {"url": "\(localURL)"},
            "remoteConnectionConfig": {
                "url": "\(remoteURL)",
                "username": "\(remoteUsername)",
                "password": "\(remotePassword)",
                "supportsNotifications": \(cloudEnabled)
            }
        }
        """
        return try JSONDecoder().decode(HomePreferences.self, from: Data(json.utf8))
    }
}
