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
import Foundation
import os.log

public enum OpenHABItemCacheError: Error, LocalizedError {
    case homeNotReachable(UUID)
    case commandFailed(any Error)
    case stateFailed(any Error)

    public var errorDescription: String? {
        switch self {
        case let .homeNotReachable(homeId):
            "Home \(homeId) is not reachable"
        case let .commandFailed(error):
            "Could not send command: \(error.localizedDescription)"
        case let .stateFailed(error):
            "Could not send state: \(error.localizedDescription)"
        }
    }
}

public actor OpenHABItemCache {
    public static let instance = OpenHABItemCache()

    private static let networkTimeout: TimeInterval = 5

    private var networkTrackers: [UUID: NetworkTracker] = [:]

    public var items: [UUID: [OpenHABItem]] = [:]
    private let ttl: TimeInterval = 20
    var lastLoad: [UUID: Date] = [:]

    private init() {}

    public func getAllCachedItems() async -> [UUID: [OpenHABItem]] {
        await reloadCacheIfNeeded(homes: Preferences.shared.listStoredHomes())
        return items
    }

    public func getCachedItems(home: UUID) async -> [OpenHABItem]? {
        await reloadCacheIfNeeded(homes: [home])
        return items[home]
    }

    public func getCachedItem(name: String, home: UUID) async -> [OpenHABItem]? {
        await reloadCacheIfNeeded(homes: [home])
        return items[home]?.filter { $0.name == name }
    }

    public func getItemUncached(name: String, home: UUID) async -> OpenHABItem? {
        guard let networkTracker = await assureNetworkTracker(homeId: home) else {
            Logger.itemCache.error("Home \(home) not reachable")
            return nil
        }
        return try? await networkTracker.getItemByName(id: name)
    }

    public func sendCommand(to item: OpenHABItem, home: UUID, command: String) async throws {
        guard let networkTracker = await assureNetworkTracker(homeId: home) else {
            Logger.itemCache.error("Home \(home) not reachable")
            throw OpenHABItemCacheError.homeNotReachable(home)
        }

        do {
            try await networkTracker.send(to: item, command: command)
        } catch {
            Logger.itemCache.info("Could not send command: \(error.localizedDescription)")
            throw OpenHABItemCacheError.commandFailed(error)
        }
    }

    public func sendState(_ item: OpenHABItem, home: UUID, state: String) async throws {
        guard let networkTracker = await assureNetworkTracker(homeId: home) else {
            Logger.itemCache.error("Home \(home) not reachable")
            throw OpenHABItemCacheError.homeNotReachable(home)
        }

        do {
            try await networkTracker.updateState(item: item, state: state)
        } catch {
            Logger.itemCache.info("Could not send state: \(error.localizedDescription)")
            throw OpenHABItemCacheError.stateFailed(error)
        }
    }

    public func reloadCacheIfNeeded(homes: [UUID]) async {
        let homesNeedingReload = homes.filter { Date.now.timeIntervalSince(lastLoad[$0] ?? Date.distantPast) > ttl }
        Logger.itemCache.info("Cache reload needed for homes \(homesNeedingReload)")
        await forceCacheReload(homes: homesNeedingReload)
    }

    public func forceCacheReload(homes: [UUID]) async {
        Logger.itemCache.info("force cache reload for homes: \(homes)")
        do {
            let loadedItems = try await loadNonGroupItemsForHomes(homes)
            Logger.itemCache.info("Store loaded items in cache")
            homes.forEach { items[$0] = loadedItems[$0] }
            let now = Date.now
            homes.forEach { lastLoad[$0] = now }
            let itemCounts = items.map { ($0.key, $0.value.count) }
            Logger.itemCache.info("Loaded \(itemCounts) items to cache")
        } catch {
            Logger.itemCache.error("Could not reload \(error.localizedDescription)")
        }
    }

    public func forceCacheReload() async {
        Logger.itemCache.info("forced cache reload for all homes")
        let homes = await Preferences.shared.listStoredHomes()
        // some house keeping
        let networkTrackersToRemove = networkTrackers.filter { !homes.contains($0.key) }
        for networkTracker in networkTrackersToRemove {
            Logger.itemCache.info("Stopping network tracker for nonexisting home \(networkTracker.key)")
            await networkTracker.value.stopTracking()
            networkTrackers.removeValue(forKey: networkTracker.key)
        }
        items = [:]
        lastLoad = [:]
        await forceCacheReload(homes: homes)
    }

    func matchingItemNames(_ itemsList: [OpenHABItem], searchTerm: String? = nil, types: [OpenHABItem.ItemType]? = nil) -> [String] {
        itemsList
            .filtered(by: searchTerm, for: types)
            .map(\.name)
            .sorted()
    }

    private func loadNonGroupItemsForHomes(_ homes: [UUID]) async throws -> [UUID: [OpenHABItem]] {
        let allItemsArray = try await loadItemsForHomes(homes).map { (uuid, items) in (uuid, items.filter { $0.type != .group }) }
        return Dictionary(uniqueKeysWithValues: allItemsArray)
    }

    private func loadItemsForHomes(_ homes: [UUID]) async throws -> [UUID: [OpenHABItem]] {
        await withThrowingTaskGroup { @Sendable group in
            for homeId in homes {
                group.addTask {
                    Logger.itemCache.info("Loading items for home \(homeId)")
                    // TODO: consider the possibility that two local connections might be the same
                    guard let items = await self.loadItems(homeId: homeId) else {
                        Logger.itemCache.error("Item search for home with id \(homeId) failed")
                        return (id: homeId, items: [] as [OpenHABItem])
                    }
                    Logger.itemCache.info("Loaded \(items.count) items for home \(homeId)")
                    return (id: homeId, items: items)
                }
            }
            let homeItemsDictionary: [UUID: [OpenHABItem]] = [:]
            let allHomeItems = try? await group.reduce(into: homeItemsDictionary) { partialResult, nextElement in
                Logger.itemCache.debug("Found \(nextElement.items.count) items for \(nextElement.id)")
                partialResult[nextElement.id] = nextElement.items
            }
            Logger.itemCache.info("loading items for homes \(homes) finished")
            guard let allHomeItems else {
                Logger.itemCache.error("Item search failed!")
                return [:]
            }
            return allHomeItems
        }
    }

    private func loadItems(homeId: UUID) async -> [OpenHABItem]? {
        guard let networkTracker = await assureNetworkTracker(homeId: homeId) else {
            Logger.itemCache.error("Home \(homeId) not reachable")
            return nil
        }
        return try? await networkTracker.getStaticItems()
    }

    private func assureNetworkTracker(homeId: UUID) async -> NetworkTracker? {
        if networkTrackers[homeId] == nil, let homePreferences = await Preferences.shared.storedHomes[homeId] {
            let tracker = NetworkTracker(timeout: OpenHABItemCache.networkTimeout)
            networkTrackers[homeId] = tracker
            await tracker.startTracking(connectionConfigurations: [homePreferences.localConnectionConfig, homePreferences.remoteConnectionConfig])
        }
        // TODO: do we need to make sure / wait that the connection is live?
        return networkTrackers[homeId]
    }
}

public extension [OpenHABItem] {
    func filtered(by searchTerm: String? = nil, for types: [OpenHABItem.ItemType]? = nil) -> [OpenHABItem] {
        // TODO: maybe allow home name for filtering and fuzzier search
        filter {
            let matchesSearchTerm = searchTerm == nil || $0.name.contains(searchTerm.orEmpty)
            let matchesType = types == nil || ($0.type.flatMap { types?.contains($0) } == true)
            return matchesSearchTerm && matchesType
        }
    }
}

public extension OpenHABItemCache {
    func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?, home: UUID) async -> [String] {
        await reloadCacheIfNeeded(homes: [home])
        return items[home]?.filter {
            let matchesSearchTerm = searchTerm == nil || $0.name.contains(searchTerm.orEmpty)
            let matchesType = types == nil || ($0.type.flatMap { types?.contains($0) } == true)
            return matchesSearchTerm && matchesType
        }
        .sorted(by: \.name)
        .map(\.name) ?? []
    }

    func getCachedItems(types: [OpenHABItem.ItemType]?, home: UUID) async -> [OpenHABItem] {
        await reloadCacheIfNeeded(homes: [home])
        return items[home]?.filter { types == nil || ($0.type.flatMap { types?.contains($0) } == true) }.sorted(by: \.name) ?? []
    }

    func searchItems(searchTerm: String, types: [OpenHABItem.ItemType]? = nil) async -> [UUID: [OpenHABItem]] {
        let allItems = await getAllCachedItems()
        var result: [UUID: [OpenHABItem]] = [:]

        for (homeId, homeItems) in allItems {
            let filtered = homeItems.filter { item in
                let matchesSearch = item.name.localizedCaseInsensitiveContains(searchTerm) ||
                    item.label.localizedCaseInsensitiveContains(searchTerm)
                let matchesType = types == nil || (item.type.flatMap { types?.contains($0) } == true)
                return matchesSearch && matchesType
            }
            if !filtered.isEmpty {
                result[homeId] = filtered
            }
        }

        return result
    }
}
