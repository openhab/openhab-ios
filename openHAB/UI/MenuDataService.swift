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
    /// What the menu loads. Each part has its own task, so a slow one does not hold back the others.
    private enum LoadPart: CaseIterable {
        case server, sitemaps, tiles, pages
    }

    /// The loads in progress, at most one per part: starting a load cancels the one before it.
    private var loadTasks: [LoadPart: Task<Void, Never>] = [:]
    /// `true` while any part is loading.
    var isLoading: Bool {
        !loadTasks.isEmpty
    }

    /// `true` while `MainActorNetworkTracker` reports an active connection.
    private(set) var isConnected = false

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
        // A new connection cancels the load of the one before it, so only the latest one is ever shown.
        Task { [weak self] in
            for await state in await networkTracker.stateStream() {
                guard let self else { break }
                isConnected = state.activeConnection != nil
                // Connection loss: retain the last-good snapshot — do NOT clear.
                // New connection: fetch without wiping first so the menu stays
                // populated until fresh data arrives.
                guard let activeConnection = state.activeConnection else { continue }
                load(from: activeConnection)
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
    }

    #endif

    /// Stops the load in progress and clears all data immediately (use for user-initiated refresh or explicit resets).
    func clearAll() {
        #if DEBUG
        if isUITestInjected {
            return
        }
        #endif
        cancelLoad()
        sitemaps = []
        uiTiles = []
        uiPages = []
    }

    /// Call on home switch: cancels the loads and clears the data.
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
        load(from: connection)
    }

    /// Re-fetches all menu data from the currently active connection without clearing,
    /// so the menu stays populated until fresh data arrives (pull-to-refresh, menu open).
    /// Returns when all parts are loaded. A cancelled caller does not cancel the loads: they are
    /// tasks of their own, which only a newer load or a reset cancels.
    func reload(networkTracker: MainActorNetworkTracker = .shared) async {
        #if DEBUG
        reloadCount += 1
        #endif
        guard let connection = networkTracker.activeConnection else { return }
        load(from: connection)
        for task in Array(loadTasks.values) {
            await task.value
        }
    }

    /// What pull-to-refresh runs.
    func refresh(networkTracker: MainActorNetworkTracker = .shared) async {
        await reload(networkTracker: networkTracker)
    }

    /// Starts loading every part of the menu, each in a task of its own, and cancels the loads before.
    private func load(from connection: ConnectionInfo) {
        #if DEBUG
        if isUITestInjected {
            return
        }
        #endif
        let service: OpenAPIService
        do {
            service = try OpenAPIService(connectionConfiguration: connection.configuration)
        } catch {
            Logger.drawerView.error("Failed to initialize OpenAPIService: \(error.localizedDescription)")
            // Retain existing snapshot on connection-level failure.
            return
        }
        let rootUrl = connection.configuration.url
        // What `GET /rest/` says about the server: its version and endpoints, which decide what
        // the Main UI entries of the menu offer (chat, administration, sign-in).
        start(.server, fetch: { try await MainUIServer(service.getRoot()) }, apply: { self.server = $0 })
        start(
            .sitemaps,
            fetch: { try await Self.filterAndSortSitemaps(service.openHABSitemaps()) },
            apply: { self.sitemaps = $0 }
        )
        start(.tiles, fetch: { try await service.getUITiles() }, apply: { self.uiTiles = $0 })
        start(.pages, fetch: { try await service.getUIPages(rootUrl: rootUrl) }, apply: { self.uiPages = $0 })
    }

    /// Runs one part's fetch in its own task and hands the result to `apply`. A part that failed
    /// leaves what the menu has.
    private func start<Value>(_ part: LoadPart,
                              fetch: @escaping @MainActor () async throws -> Value,
                              apply: @escaping @MainActor (Value) -> Void) {
        loadTasks[part]?.cancel()
        loadTasks[part] = Task {
            let value: Value?
            do {
                value = try await fetch()
            } catch {
                Logger.drawerView.error("Failed to fetch \(String(describing: part)): \(error.localizedDescription)")
                value = nil
            }
            // Critical section: from the last cancellation check to handing over the data there is
            // no suspension point, and this class is on the main actor, so no other load can run in
            // between. A cancelled load never reaches the menu, and the one that replaced it, or
            // the reset that cancelled it, owns `loadTasks[part]`.
            guard !Task.isCancelled else { return }
            if let value {
                apply(value)
            }
            loadTasks[part] = nil
        }
    }

    private func cancelLoad() {
        for task in loadTasks.values {
            task.cancel()
        }
        loadTasks = [:]
    }
}
