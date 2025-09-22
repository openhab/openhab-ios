// Copyright (c) 2010-2025 Contributors to the openHAB project
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

public actor OpenHABItemCache {
    public static let instance = OpenHABItemCache()

    private var networkTrackers: [UUID: NetworkTracker] = [:]

    public var items: [UUID: [OpenHABItem]] = [:]
    private let ttl: TimeInterval = 20
    var lastLoad: [UUID: Date] = [:]

    private let logger = Logger(subsystem: "org.openhab.app.openHABIntents", category: "OpenHABItemCache")

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

    public func sendCommand(to item: OpenHABItem, home: UUID, command: String) async {
        guard let networkTracker = await assureNetworkTracker(homeId: home) else {
            logger.error("Home \(home) not reachable")
            return
        }

        do {
            try await networkTracker.send(to: item, command: command)
        } catch {
            logger.info("Could not send command: \(error.localizedDescription)")
        }
    }

    public func sendState(_ item: OpenHABItem, home: UUID, state: String) async {
        guard let networkTracker = await assureNetworkTracker(homeId: home) else {
            logger.error("Home \(home) not reachable")
            return
        }

        do {
            try await networkTracker.updateState(item: item, state: state)
        } catch {
            logger.info("Could not send state: \(error.localizedDescription)")
        }
    }

    public func reloadCacheIfNeeded(homes: [UUID]) async {
        let homesNeedingReload = homes.filter { Date.now.timeIntervalSince(lastLoad[$0] ?? Date.distantPast) > ttl }
        await forceCacheReload(homes: homesNeedingReload)
    }

    public func forceCacheReload(homes: [UUID]) async {
        logger.info("reload items")
        do {
            let loadedItems = try await loadNonGroupItemsForHomes(homes)
            homes.forEach { items[$0] = loadedItems[$0] }
            let now = Date.now
            homes.forEach { lastLoad[$0] = now }
            let itemCounts = items.map { ($0.key, $0.value.count) }
            logger.info("Loaded \(itemCounts) items to cache")
        } catch {
            logger.error("Could not reload \(error.localizedDescription)")
        }
    }

    public func forceCacheReload() async {
        let homes = await Preferences.shared.listStoredHomes()
        // some house keeping
        let networkTrackersToRemove = networkTrackers.filter { !homes.contains($0.key) }
        for networkTracker in networkTrackersToRemove {
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
                    // TODO: consider the possibility that two local connections might be the same
                    guard let items = await self.loadItems(homeId: homeId) else {
                        self.logger.error("Item search for home with id \(homeId) failed")
                        return (id: homeId, items: [] as [OpenHABItem])
                    }
                    return (id: homeId, items: items)
                }
            }
            let homeItemsDictionary: [UUID: [OpenHABItem]] = [:]
            let allHomeItems = try? await group.reduce(into: homeItemsDictionary) { partialResult, nextElement in
                logger.debug("Found \(nextElement.items.count) items for \(nextElement.id)")
                partialResult[nextElement.id] = nextElement.items
            }
            guard let allHomeItems else {
                logger.error("Item search failed!")
                return [:]
            }
            return allHomeItems
        }
    }

    private func loadItems(homeId: UUID) async -> [OpenHABItem]? {
        guard let networkTracker = await assureNetworkTracker(homeId: homeId) else {
            logger.error("Home \(homeId) not reachable")
            return nil
        }
        return try? await networkTracker.getItems()
    }

    private func assureNetworkTracker(homeId: UUID) async -> NetworkTracker? {
        if networkTrackers[homeId] == nil, let homePreferences = await Preferences.shared.storedHomes[homeId] {
            let tracker = NetworkTracker()
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
            (searchTerm == nil || $0.name.contains(searchTerm.orEmpty)) &&
                (types == nil || ($0.type != nil && types!.contains($0.type!)))
        }
    }
}
