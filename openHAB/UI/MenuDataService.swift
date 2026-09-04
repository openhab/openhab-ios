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

import Observation
import OpenHABCore
import os.log

/// Provides menu data (sitemaps, tiles, pages) for the navigation menu.
/// Extracted from DrawerView for testability and reuse.
@MainActor
@Observable
class MenuDataService {
    var sitemaps: [OpenHABSitemap] = []
    var uiTiles: [OpenHABUiTile] = []
    var uiPages: [OpenHABUIPage] = []
    var isLoading = false
    /// `true` while `MainActorNetworkTracker` reports an active connection.
    private(set) var isConnected = false
    /// `true` once the **current** home has had at least one successful data fetch.
    /// Resets to `false` on every home switch so the "Home" MainUI entry is re-gated
    /// on each switch (consistent with sitemaps/pages behaviour).
    var hasSuccessfullyLoaded = false

    init() {
        // Observe activeConnection using Swift Concurrency — `for await` on
        // `$publisher.values` participates in structured concurrency and
        // respects @MainActor isolation without AnyCancellable bookkeeping.
        // Deliveries are serialised: the loop waits for fetchData to complete
        // before processing the next connection change, preventing race conditions.
        Task { @MainActor [weak self] in
            for await activeConnection in MainActorNetworkTracker.shared.$activeConnection.values {
                guard let self else { break }
                isConnected = activeConnection != nil
                // Connection loss: retain the last-good snapshot — do NOT clear.
                // New connection: fetch without wiping first so the menu stays
                // populated until fresh data arrives.
                guard let activeConnection else { continue }
                await fetchData(activeConnection: activeConnection)
            }
        }
    }

    /// Clears all data immediately (use for user-initiated refresh or explicit resets).
    func clearAll() {
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
        clearAll()
        hasSuccessfullyLoaded = false
        isConnected = false
    }

    /// Returns the display label for a tile or page URL, or an empty string if not found.
    func label(forURL url: String) -> String {
        if let tile = uiTiles.first(where: { $0.url == url }) { return tile.name }
        if let page = uiPages.first(where: { $0.url == url }) { return page.label }
        return ""
    }

    /// Re-fetches all menu data from the currently active connection, clearing first.
    func refresh() {
        let connection = MainActorNetworkTracker.shared.activeConnection
        clearAll()
        Task { await fetchData(activeConnection: connection) }
    }

    func fetchData(activeConnection: ConnectionInfo?) async {
        guard let activeConnection else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)
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

    /// Filters out `_default` sitemap when others exist, then sorts per user preference.
    static func filterAndSortSitemaps(_ sitemaps: [OpenHABSitemap]) async -> [OpenHABSitemap] {
        let sortBy = SortSitemapsOrder(rawValue: (await Preferences.shared.currentHomePreferences).sortSitemapsBy) ?? .label
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
}
