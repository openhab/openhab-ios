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
import Observation
import OpenHABCore
import os.log

#if DEBUG
/// The `UITestServer` launch environment: `{"version":"5.0.0","endpoints":["items"],"pages":[{"uid":"kitchen","label":"Kitchen","visibleTo":["role:user"]}]}`.
struct UITestServerFixture: Decodable {
    struct Page: Decodable {
        let uid: String
        let label: String
        let visibleTo: [String]?
    }

    struct Sitemap: Decodable {
        let name: String
        let label: String
    }

    let version: String?
    let endpoints: [String]
    let pages: [Page]?
    /// Sitemaps for the menu to list. The sitemap itself is still loaded from the active connection.
    let sitemaps: [Sitemap]?

    var menuSitemaps: [OpenHABSitemap] {
        (sitemaps ?? []).map { OpenHABSitemap(name: $0.name, icon: "", label: $0.label, link: "", page: nil) }
    }

    var server: MainUIServer {
        MainUIServer(majorVersion: version.flatMap { Int($0.split(separator: ".").first ?? "") }, endpoints: Set(endpoints))
    }

    var menuPages: [OpenHABUIPage] {
        (pages ?? []).enumerated().map { index, page in
            OpenHABUIPage(
                uid: page.uid,
                label: page.label,
                icon: "",
                order: OpenHABUIPage.defaultOrder + index,
                url: "/page/\(page.uid)",
                visibleTo: page.visibleTo ?? []
            )
        }
    }

    init?(json: String) {
        guard let fixture = try? JSONDecoder().decode(Self.self, from: Data(json.utf8)) else { return nil }
        self = fixture
    }
}
#endif

/// Provides menu data (sitemaps, tiles, pages) for the navigation menu.
/// Extracted from DrawerView for testability and reuse.
/// `@Observable` so an open menu re-renders as soon as a fetch completes.
@MainActor
@Observable
class MenuDataService {
    var sitemaps: [OpenHABSitemap] = []
    var uiTiles: [OpenHABUiTile] = []
    var uiPages: [OpenHABUIPage] = []
    /// What `GET /rest/` said about the server. Nil until it has, and again after a home switch.
    var server: MainUIServer?
    /// Fetches running now. The connection stream, opening the menu and pull-to-refresh can
    /// each start one while another is still running.
    private(set) var fetchesInFlight = 0
    /// `true` until the last of any overlapping fetches has ended.
    var isLoading: Bool {
        fetchesInFlight > 0
    }

    /// `true` while `MainActorNetworkTracker` reports an active connection.
    private(set) var isConnected = false
    /// `true` once the **current** home has had at least one successful data fetch.
    /// Resets to `false` on every home switch so the "Home" MainUI entry is re-gated
    /// on each switch (consistent with sitemaps/pages behaviour).
    var hasSuccessfullyLoaded = false

    #if DEBUG
    /// How often `reload()` ran, so a UI test can tell that a pull-to-refresh reloaded the menu.
    private(set) var reloadCount = 0

    #endif

    #if DEBUG
    /// Set by `injectForUITest`: what the test put in is not replaced by what a server says.
    private var isUITestInjected = false

    #endif

    init(networkTracker: NetworkTracker = .shared) {
        // Observe connection changes via NetworkTracker.stateStream() —
        // an AsyncStream that delivers one coherent NetworkState per change.
        // Deliveries are serialised: the loop waits for fetchData to complete
        // before processing the next connection change, preventing race conditions.
        Task { [weak self] in
            for await state in await networkTracker.stateStream() {
                guard let self else { break }
                isConnected = state.activeConnection != nil
                // Connection loss: retain the last-good snapshot — do NOT clear.
                // New connection: fetch without wiping first so the menu stays
                // populated until fresh data arrives.
                guard let activeConnection = state.activeConnection else { continue }
                await fetchData(activeConnection: activeConnection)
            }
        }
    }

    /// Filters out `_default` sitemap when others exist, then sorts per user preference.
    static func filterAndSortSitemaps(_ sitemaps: [OpenHABSitemap]) async -> [OpenHABSitemap] {
        let sortBy = await SortSitemapsOrder(rawValue: (Preferences.shared.currentHomePreferences).sortSitemapsBy) ?? .label
        return filterAndSortSitemaps(sitemaps, sortBy: sortBy)
    }

    /// Filters and sorts sitemaps with an explicit sort order. Pure function for testing.
    static func filterAndSortSitemaps(_ sitemaps: [OpenHABSitemap], sortBy: SortSitemapsOrder) -> [OpenHABSitemap] {
        var result = sitemaps
        if result.last?.name == "_default", result.count > 1 {
            result = Array(result.dropLast())
        }
        switch sortBy {
        case .label:
            result.sort { $0.label < $1.label }
        case .name:
            result.sort { $0.name < $1.name }
        }
        return result
    }

    #if DEBUG

    /// Stands in for what the server returns, so UI tests need no server.
    func injectForUITest(server: MainUIServer, pages: [OpenHABUIPage], sitemaps: [OpenHABSitemap] = []) {
        isUITestInjected = true
        self.server = server
        uiPages = pages
        self.sitemaps = sitemaps
        hasSuccessfullyLoaded = true
    }

    #endif

    /// Clears all data immediately (use for user-initiated refresh or explicit resets).
    func clearAll() {
        #if DEBUG
        if isUITestInjected {
            return
        }
        #endif
        sitemaps = []
        uiTiles = []
        uiPages = []
    }

    /// Call on home switch: clears data and resets the load gate.
    /// Does NOT start an eager fetch — `MainActorNetworkTracker.shared.activeConnection`
    /// still belongs to the old home at this point (the NetworkConnectionService
    /// re-evaluates asynchronously). The `init()` Combine subscription fires once the
    /// tracker reconnects to the new home and handles all fetching from there.
    func clearForHomeSwitch() {
        #if DEBUG
        if isUITestInjected {
            return
        }
        #endif
        clearAll()
        server = nil
        hasSuccessfullyLoaded = false
        isConnected = false
    }

    /// Returns the display label for a tile or page URL, or an empty string if not found.
    func label(forURL url: String) -> String {
        if let tile = uiTiles.first(where: { $0.url == url }) {
            return tile.name
        }
        if let page = uiPages.first(where: { $0.url == url }) {
            return page.label
        }
        return ""
    }

    /// Empties the menu and fetches it again from the active connection (header reload button,
    /// saved preferences). Without a connection it keeps what it has, as on connection loss:
    /// nothing would fill an emptied menu until the next connection change.
    func clearAndReload(networkTracker: MainActorNetworkTracker = .shared) {
        guard let connection = networkTracker.activeConnection else { return }
        clearAll()
        Task { await fetchData(activeConnection: connection) }
    }

    /// Re-fetches all menu data from the currently active connection without clearing,
    /// so the menu stays populated until fresh data arrives (pull-to-refresh, menu open).
    func reload(networkTracker: MainActorNetworkTracker = .shared) async {
        #if DEBUG
        reloadCount += 1
        #endif
        await fetchData(activeConnection: networkTracker.activeConnection)
    }

    /// What pull-to-refresh runs. SwiftUI cancels the refresh task when the menu re-renders while
    /// it loads, which would cancel the requests and leave the old entries in place. So `reload`
    /// runs in a task of its own that the refresh only waits for.
    func refresh(networkTracker: MainActorNetworkTracker = .shared) async {
        await refresh { await self.reload(networkTracker: networkTracker) }
    }

    /// Waits for `work`, which a cancellation of the caller does not reach.
    func refresh(running work: @escaping @MainActor () async -> Void) async {
        await Task { await work() }.value
    }

    func fetchData(activeConnection: ConnectionInfo?) async {
        guard let activeConnection else { return }
        #if DEBUG
        if isUITestInjected {
            return
        }
        #endif
        await whileLoading {
            await fetchAll(from: activeConnection)
        }
    }

    /// Runs `work` as one fetch, counted in `fetchesInFlight`.
    func whileLoading(_ work: @MainActor () async -> Void) async {
        fetchesInFlight += 1
        defer { fetchesInFlight -= 1 }
        await work()
    }

    private func fetchAll(from activeConnection: ConnectionInfo) async {
        do {
            let openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)
            await fetchServer(using: openAPIService)
            await fetchSitemaps(using: openAPIService)
            await fetchTiles(using: openAPIService)
            await fetchPages(using: openAPIService, rootUrl: activeConnection.configuration.url)
            // Service init succeeded — home is reachable; gate the "Home" entry.
            hasSuccessfullyLoaded = true
        } catch {
            Logger.drawerView.error("Failed to initialize OpenAPIService: \(error.localizedDescription)")
            // Retain existing snapshot on connection-level failure.
        }
    }

    private func fetchServer(using service: OpenAPIService) async {
        do {
            server = try await MainUIServer(service.getRoot())
        } catch {
            Logger.drawerView.error("Failed to fetch server properties: \(error.localizedDescription)")
            // Retain the existing server on failure.
        }
    }

    private func fetchSitemaps(using service: OpenAPIService) async {
        do {
            var fetched = try await service.openHABSitemaps()
            fetched = await Self.filterAndSortSitemaps(fetched)
            sitemaps = fetched
        } catch {
            Logger.drawerView.error("Failed to fetch sitemaps: \(error.localizedDescription)")
            // Retain existing sitemaps on individual-fetch failure.
        }
    }

    private func fetchTiles(using service: OpenAPIService) async {
        do {
            uiTiles = try await service.getUITiles()
            Logger.drawerView.info("Fetched UI tiles successfully")
        } catch {
            Logger.drawerView.error("Failed to fetch UI tiles: \(error.localizedDescription)")
            // Retain existing tiles on individual-fetch failure.
        }
    }

    private func fetchPages(using service: OpenAPIService, rootUrl: String) async {
        do {
            uiPages = try await service.getUIPages(rootUrl: rootUrl)
            Logger.drawerView.info("Fetched UI pages successfully")
        } catch {
            Logger.drawerView.error("Failed to fetch UI pages: \(error.localizedDescription)")
            // Retain existing pages on individual-fetch failure.
        }
    }
}
