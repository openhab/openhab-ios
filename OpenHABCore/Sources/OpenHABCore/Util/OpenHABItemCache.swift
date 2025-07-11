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

public protocol ItemCacheProtocol {
    func getItem(name: String) async -> OpenHABItem?
    func sendCommand(_ item: OpenHABItem, commandToSend: String) async
    func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?) async -> [String]
    func sendState(_ item: OpenHABItem, stateToSend: String) async
}

public actor OpenHABItemCache {
    private static let logger = Logger(subsystem: "org.openhab.app.openHABIntents", category: "OpenHABItemCache")
    public static let instance = OpenHABItemCache()

    private lazy var setupTask: Task<Void, Never> = Task { [weak self] in
        await self?.setup()
    }

    public var items: [UUID: [OpenHABItem]]?
    private let ttl: TimeInterval = 20
    var lastLoad = Date()

    private let logger = Logger(subsystem: "org.openhab.app.openHABIntents", category: "OpenHABItemCache")

    private init() {}

    static func getNonGroupItemsForAllHomes() async throws -> [UUID: [OpenHABItem]] {
        let allItemsArray = try await getItemsForAllHomes().map { (uuid, items) in (uuid, items.filter { $0.type != .group }) }
        return Dictionary(uniqueKeysWithValues: allItemsArray)
    }

    static func getItemsForAllHomes() async throws -> [UUID: [OpenHABItem]] {
        await withThrowingTaskGroup { @Sendable group in
            for homeId in await Preferences.storedHomes.keys {
                group.addTask {
                    // TODO: consider the possibility that two local connections might be the same
                    guard let items = await OpenHABItemCache.getItems(homeId: homeId) else {
                        logger.error("Item search for home with id \(homeId) failed")
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

    static func getItems(homeId: UUID) async -> [OpenHABItem]? {
        if await homeId == Preferences.currentHomePreferences.id {
            return try? await NetworkTracker.shared.getItems()
        } else {
            guard let homePreferences = await Preferences.storedHomes[homeId] else {
                Logger(subsystem: "org.openhab.app.watchkitapp", category: "OpenHABItemCache")
                    .error("No home for id \(homeId) found")
                return nil
            }
            return await performWithTemporaryNetworkTracker(for: homePreferences) { networkTracker in
                try? await networkTracker.getItems()
            }
        }
    }

    static func performWithTemporaryNetworkTracker<T: Sendable>(for home: HomePreferences,
                                                                actions: (_ networkTracker: NetworkTracker) async throws -> T) async rethrows -> T {
        let networkTracker = NetworkTracker()
        await networkTracker.startTracking(connectionConfigurations: [home.remoteConnectionConfig, home.localConnectionConfig])
        // TODO: I would love to use defer here to make sure the network tracker stops, but stopTracking() is async and not allowed in defer.
        let result: T
        do {
            result = try await actions(networkTracker)
        } catch {
            await networkTracker.stopTracking()
            throw error
        }
        await networkTracker.stopTracking()
        return result
    }

    public func waitUntilReady() async {
        await setupTask.value
    }

    public func setup() async {
        let connection1: ConnectionConfiguration = await Preferences.currentHomePreferences.localConnectionConfig
        let connection2: ConnectionConfiguration = await Preferences.currentHomePreferences.remoteConnectionConfig
        logger.info("Local: \(connection1.url), Remote: \(connection2.url)")
        await NetworkTracker.shared.startTracking(connectionConfigurations: [connection1, connection2])
    }

    public func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?) async -> [String] {
        logger.info("getItemNames")
        guard let items else {
            return await reload(searchTerm: searchTerm, types: types)
        }

        return items.flatMap { (_, items: [OpenHABItem]) in items }
            .filtered(by: searchTerm, for: types)
            .sorted(by: \.name)
            .map(\.name)
    }

    public func getItem(name: String) async -> OpenHABItem? {
        logger.info("getItem")
        let now = Date()

        if items == nil || now.timeIntervalSince(lastLoad) > ttl {
            return await reload(name: name)
        }
        return getItem(name)
    }

    func getItem(_ name: String) -> OpenHABItem? {
        // TODO: consider associated home
        items?.flatMap { (_: UUID, items: [OpenHABItem]) in items }
            .first { $0.name == name }
    }

    public func sendCommand(_ item: OpenHABItem, commandToSend command: String) async {
        do {
            try await sendCommand(to: item, command: command)
        } catch {
            logger.info("Could not send command: \(error.localizedDescription)")
        }
    }

    func sendCommand(to item: OpenHABItem, home: UUID? = nil, command: String) async throws {
        if let home, await home != Preferences.currentHomePreferences.id {
            guard let homeConfig = await Preferences.storedHomes[home] else { return } // TODO: log warning (or throw?)
            try await OpenHABItemCache.performWithTemporaryNetworkTracker(for: homeConfig) { networkTracker in
                try await networkTracker.send(to: item, command: command)
            }
        } else {
            try await NetworkTracker.shared.send(to: item, command: command)
        }
    }

    public func sendState(_ item: OpenHABItem, stateToSend state: String) async {
        do {
            try await sendState(for: item, state: state)
        } catch {
            logger.info("Could not send state: \(error.localizedDescription)")
        }
    }

    func sendState(for item: OpenHABItem, home: UUID? = nil, state: String) async throws {
        if let home, await home != Preferences.currentHomePreferences.id {
            guard let homeConfig = await Preferences.storedHomes[home] else { return } // TODO: log warning (or throw?)
            try await OpenHABItemCache.performWithTemporaryNetworkTracker(for: homeConfig) { networkTracker in
                try await networkTracker.updateState(item: item, state: state)
            }
        } else {
            try await NetworkTracker.shared.updateState(item: item, state: state)
        }
    }

    public func reload(searchTerm: String?, types: [OpenHABItem.ItemType]?) async -> [String] {
        logger.info("OpenHABItemCache Loading items ")

        do {
            items = try await OpenHABItemCache.getNonGroupItemsForAllHomes()
            // swiftformat:disable next redundantSelf
            lastLoad = Date()
            logger.info("Loaded \(self.items?.count ?? 0) items to cache")
            return items?.flatMap { (_: UUID, items: [OpenHABItem]) in
                items
            }
            .filtered(by: searchTerm, for: types)
            .sorted(by: \.name)
            .map(\.name) ?? []
        } catch {
            logger.error("Could not reload \(error.localizedDescription)")
            return []
        }
    }

    public func reload(name: String) async -> OpenHABItem? {
        do {
            items = try await OpenHABItemCache.getNonGroupItemsForAllHomes()
            return items?.flatMap { (_: UUID, items: [OpenHABItem]) in
                items
            }
            .first { $0.name == name }
        } catch {
            logger.error("Could not reload \(error.localizedDescription)")
            return nil
        }
    }
}

extension OpenHABItemCache: ItemCacheProtocol {}

private extension [OpenHABItem] {
    func filtered(by searchTerm: String?, for types: [OpenHABItem.ItemType]?) -> [OpenHABItem] {
        // TODO: maybe allow home name for filtering and fuzzier search
        filter {
            (searchTerm == nil || $0.name.contains(searchTerm.orEmpty)) &&
                (types == nil || ($0.type != nil && types!.contains($0.type!)))
        }
    }
}
