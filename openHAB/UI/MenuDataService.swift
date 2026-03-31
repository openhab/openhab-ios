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

/// Provides menu data (sitemaps, tiles) for the navigation menu.
/// Extracted from DrawerView for testability and reuse.
@MainActor
class MenuDataService: ObservableObject {
    @Published var sitemaps: [OpenHABSitemap] = []
    @Published var uiTiles: [OpenHABUiTile] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        MainActorNetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activeConnection in
                Task { [weak self] in
                    await self?.fetchData(activeConnection: activeConnection)
                }
            }
            .store(in: &cancellables)
    }

    func fetchData(activeConnection: ConnectionInfo?) async {
        guard let activeConnection else { return }

        do {
            let openAPIService = try OpenAPIService(connectionConfiguration: activeConnection.configuration)
            await fetchSitemaps(using: openAPIService)
            await fetchTiles(using: openAPIService)
        } catch {
            Logger.drawerView.error("Failed to initialize OpenAPIService: \(error.localizedDescription)")
            sitemaps = []
            uiTiles = []
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
