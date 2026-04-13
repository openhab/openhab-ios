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

import Combine
import OpenHABCore
import os.log

/// Provides menu data (sitemaps, tiles, pages) for the navigation menu.
/// Extracted from DrawerView for testability and reuse.
@MainActor
class MenuDataService: ObservableObject {
    @Published var sitemaps: [OpenHABSitemap] = []
    @Published var uiTiles: [OpenHABUiTile] = []
    @Published var uiPages: [OpenHABUIPage] = []
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        MainActorNetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activeConnection in
                self?.clearAll()
                Task { [weak self] in
                    await self?.fetchData(activeConnection: activeConnection)
                }
            }
            .store(in: &cancellables)
    }

    /// Clears all data immediately (shows empty state while fetching).
    func clearAll() {
        sitemaps = []
        uiTiles = []
        uiPages = []
    }

    /// Returns the display label for a tile or page URL, or an empty string if not found.
    func label(forURL url: String) -> String {
        if let tile = uiTiles.first(where: { $0.url == url }) { return tile.name }
        if let page = uiPages.first(where: { $0.url == url }) { return page.label }
        return ""
    }

    /// Re-fetches all menu data from the currently active connection.
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
        } catch {
            Logger.drawerView.error("Failed to initialize OpenAPIService: \(error.localizedDescription)")
            sitemaps = []
            uiTiles = []
            uiPages = []
        }
    }

    private func fetchSitemaps(using service: OpenAPIService) async {
        do {
            var fetched = try await service.openHABSitemaps()
            fetched = Self.filterAndSortSitemaps(fetched)
            sitemaps = fetched
        } catch {
            Logger.drawerView.error("Failed to fetch sitemaps: \(error.localizedDescription)")
            sitemaps = []
        }
    }

    private func fetchTiles(using service: OpenAPIService) async {
        do {
            uiTiles = try await service.getUITiles()
            Logger.drawerView.info("Fetched UI tiles successfully")
        } catch {
            Logger.drawerView.error("Failed to fetch UI tiles: \(error.localizedDescription)")
            uiTiles = []
        }
    }

    private func fetchPages(using service: OpenAPIService, rootUrl: String) async {
        do {
            uiPages = try await service.getUIPages(rootUrl: rootUrl)
            Logger.drawerView.info("Fetched UI pages successfully")
        } catch {
            Logger.drawerView.error("Failed to fetch UI pages: \(error.localizedDescription)")
            uiPages = []
        }
    }

    /// Filters out `_default` sitemap when others exist, and sorts per user preference.
    /// This is a pure function for testability.
    static func filterAndSortSitemaps(_ sitemaps: [OpenHABSitemap]) -> [OpenHABSitemap] {
        var result = sitemaps
        if result.last?.name == "_default", result.count > 1 {
            result = Array(result.dropLast())
        }
        let sortSitemapsBy = Preferences.shared.currentHomePreferences.sortSitemapsBy
        switch SortSitemapsOrder(rawValue: sortSitemapsBy) ?? .label {
        case .label:
            result.sort { $0.label < $1.label }
        case .name:
            result.sort { $0.name < $1.name }
        }
        return result
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
