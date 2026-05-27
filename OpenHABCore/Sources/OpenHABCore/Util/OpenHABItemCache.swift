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

private enum ItemSearchRanker {
    static func score(for item: OpenHABItem, searchTerm: String, additionalCandidates: [String] = []) -> Int? {
        let tokens = normalizedTokens(in: searchTerm)
        guard !tokens.isEmpty else {
            return 0
        }

        let candidates = [item.name, item.label] + additionalCandidates
        return candidates
            .enumerated()
            .compactMap { index, candidate in
                score(candidate: candidate, tokens: tokens).map { ($0 * 10) + index }
            }
            .min()
    }

    private static func score(candidate: String, tokens: [String]) -> Int? {
        let normalizedCandidate = normalize(candidate)
        let joinedTokens = tokens.joined()

        if normalizedCandidate == joinedTokens {
            return 0
        }

        if normalizedCandidate.hasPrefix(joinedTokens) {
            return 10
        }

        if let wordPrefixScore = wordPrefixScore(candidate: normalizedCandidate, tokens: tokens) {
            return 20 + wordPrefixScore
        }

        if let orderedTokenScore = orderedTokenScore(candidate: normalizedCandidate, tokens: tokens) {
            return 40 + orderedTokenScore
        }

        if tokens.allSatisfy(normalizedCandidate.contains) {
            return 80 + tokens.reduce(0) { partialResult, token in
                partialResult + (normalizedCandidate.distance(from: normalizedCandidate.startIndex, to: normalizedCandidate.range(of: token)?.lowerBound ?? normalizedCandidate.startIndex))
            }
        }

        return nil
    }

    private static func wordPrefixScore(candidate: String, tokens: [String]) -> Int? {
        let words = candidate
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        guard !words.isEmpty, words.count >= tokens.count else {
            return nil
        }

        var wordIndex = 0
        var score = 0

        for token in tokens {
            var matched = false

            while wordIndex < words.count {
                if words[wordIndex].hasPrefix(token) {
                    score += wordIndex
                    matched = true
                    wordIndex += 1
                    break
                }
                wordIndex += 1
            }

            guard matched else {
                return nil
            }
        }

        return score
    }

    private static func orderedTokenScore(candidate: String, tokens: [String]) -> Int? {
        var searchStartIndex = candidate.startIndex
        var previousMatchUpperBound = candidate.startIndex
        var score = 0

        for token in tokens {
            guard let range = candidate.range(of: token, range: searchStartIndex ..< candidate.endIndex) else {
                return nil
            }

            score += candidate.distance(from: previousMatchUpperBound, to: range.lowerBound)
            previousMatchUpperBound = range.upperBound
            searchStartIndex = range.upperBound
        }

        return score
    }

    private static func normalizedTokens(in searchTerm: String) -> [String] {
        normalize(searchTerm)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func normalize(_ string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public actor OpenHABItemCache {
    private struct ItemStub: Codable {
        let name: String
        let label: String
        let type: String?
    }

    public static let instance = OpenHABItemCache()

    private static let networkTimeout: TimeInterval = 5
    private static let stubsDefaultsKey = "openHABItemStubs"
    private static let sharedDefaultsSuiteName = "group.org.openhab.app"

    private var networkTrackers: [UUID: NetworkTracker] = [:]

    public var items: [UUID: [OpenHABItem]] = [:]
    private let ttl: TimeInterval = 20
    var lastLoad: [UUID: Date] = [:]
    private var cachedStubs: [String: [ItemStub]]?

    private init() {}

    private func loadedStubs() -> [String: [ItemStub]] {
        if let cached = cachedStubs { return cached }
        guard let data = UserDefaults(suiteName: Self.sharedDefaultsSuiteName)?.data(forKey: Self.stubsDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: [ItemStub]].self, from: data) else {
            return [:]
        }
        cachedStubs = decoded
        return decoded
    }

    public func getAllCachedItems() async -> [UUID: [OpenHABItem]] {
        await Preferences.prepareForAppExtensionAccess()
        await reloadCacheIfNeeded(homes: Preferences.shared.listStoredHomes())
        return items
    }

    public func getCachedItems(home: UUID) async -> [OpenHABItem]? {
        await reloadCacheIfNeeded(homes: [home])
        return items[home]
    }

    public func getCachedItem(name: String, home: UUID) async -> [OpenHABItem]? {
        await reloadCacheIfNeeded(homes: [home])
        let live = items[home]?.filter { $0.name == name }
        if let live, !live.isEmpty { return live }
        return persistedItem(name: name, home: home).map { [$0] }
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

    private func persistStubs() {
        // Merge into existing stubs so homes not in the current in-memory `items`
        // (e.g. loaded in a prior process or a different cache reload scope) are preserved.
        // A full replace would wipe stubs for homes not currently in memory, removing the
        // fallback for intents that target a home the current process hasn't loaded.
        var allStubs = loadedStubs()
        for (homeId, homeItems) in items {
            allStubs[homeId.uuidString] = homeItems.map { ItemStub(name: $0.name, label: $0.label, type: $0.type?.rawValue) }
        }
        guard let data = try? JSONEncoder().encode(allStubs) else { return }
        cachedStubs = allStubs
        UserDefaults(suiteName: Self.sharedDefaultsSuiteName)?.set(data, forKey: Self.stubsDefaultsKey)
    }

    private func persistedItem(name: String, home: UUID) -> OpenHABItem? {
        guard let stub = loadedStubs()[home.uuidString]?.first(where: { $0.name == name }) else { return nil }
        return OpenHABItem(name: stub.name, type: stub.type ?? "", state: nil, link: "", label: stub.label, groupType: nil, stateDescription: nil, commandDescription: nil, members: [], category: nil, options: nil)
    }

    private func persistedItems(home: UUID) -> [OpenHABItem] {
        (loadedStubs()[home.uuidString] ?? []).map {
            OpenHABItem(
                name: $0.name,
                type: $0.type ?? "",
                state: nil,
                link: "",
                label: $0.label,
                groupType: nil,
                stateDescription: nil,
                commandDescription: nil,
                members: [],
                category: nil,
                options: nil
            )
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
            let now = Date.now
            for (homeId, homeItems) in loadedItems {
                items[homeId] = homeItems
                lastLoad[homeId] = now
            }
            if !loadedItems.isEmpty {
                persistStubs()
            }
            let itemCounts = items.map { ($0.key, $0.value.count) }
            Logger.itemCache.info("Loaded \(itemCounts) items to cache")
        } catch {
            Logger.itemCache.error("Could not reload \(error.localizedDescription)")
        }
    }

    public func forceCacheReload() async {
        Logger.itemCache.info("forced cache reload for all homes")
        await Preferences.prepareForAppExtensionAccess()
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
                        // Return nil so the caller leaves this home's cache entry untouched,
                        // allowing getCachedOrPersistedItems to fall back to persisted stubs.
                        return nil as (id: UUID, items: [OpenHABItem])?
                    }
                    Logger.itemCache.info("Loaded \(items.count) items for home \(homeId)")
                    return (id: homeId, items: items)
                }
            }
            let homeItemsDictionary: [UUID: [OpenHABItem]] = [:]
            let allHomeItems = try? await group.reduce(into: homeItemsDictionary) { partialResult, nextElement in
                guard let nextElement else { return } // nil == connection failed; leave cache untouched
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
        #if os(watchOS) || os(macOS) || targetEnvironment(macCatalyst)
        // On watchOS and macOS, App Intents run directly in the main app process (no separate
        // extension process exists on either platform). NetworkTracker.shared is already connected
        // there, so creating private per-home NetworkTracker instances would start cold — with no
        // active connection — causing item loads to fail immediately.
        //
        // Limitation: the homeId parameter is ignored, so only the currently active home's
        // connection is used. Multi-home App Intents are an iOS-only capability.
        return NetworkTracker.shared
        #else
        await Preferences.prepareForAppExtensionAccess()
        if networkTrackers[homeId] == nil {
            let storedHomes = await Preferences.shared.storedHomes
            // Direct key lookup; fall back to matching by HomePreferences.id for stored data where
            // the dictionary key and the id field differ (can happen after certain migrations).
            let homePreferences = storedHomes[homeId] ?? storedHomes.values.first { $0.id == homeId }
            if let homePreferences {
                let tracker = NetworkTracker(timeout: OpenHABItemCache.networkTimeout)
                networkTrackers[homeId] = tracker
                await tracker.startTracking(connectionConfigurations: [homePreferences.localConnectionConfig, homePreferences.remoteConnectionConfig])
            }
        }
        // TODO: do we need to make sure / wait that the connection is live?
        return networkTrackers[homeId]
        #endif
    }
}

public extension OpenHABItemCache {
    func getCachedOrPersistedItem(name: String, home: UUID) -> OpenHABItem? {
        if let item = items[home]?.first(where: { $0.name == name }) {
            return item
        }
        let stub = persistedItem(name: name, home: home)
        if stub == nil {
            Logger.itemCache.error("Item '\(name)' not found in cache or stubs for home \(home)")
        } else {
            Logger.itemCache.info("Item '\(name)' resolved from stubs (no live cache) for home \(home)")
        }
        return stub
    }

    func getCachedOrPersistedItems(types: [OpenHABItem.ItemType]?, home: UUID) -> [OpenHABItem] {
        let sourceItems = items[home] ?? persistedItems(home: home)
        return sourceItems
            .filtered(for: types)
            .sorted(by: \.name)
    }

    func getCachedOrPersistedItems(types: [OpenHABItem.ItemType]? = nil, homes: [UUID]) -> [UUID: [OpenHABItem]] {
        var result: [UUID: [OpenHABItem]] = [:]

        for homeId in homes {
            let sourceItems = items[homeId] ?? persistedItems(home: homeId)
            result[homeId] = sourceItems
                .filtered(for: types)
                .sorted(by: \.name)
        }

        return result
    }

    func searchCachedOrPersistedItems(searchTerm: String, types: [OpenHABItem.ItemType]? = nil, homes: [UUID]? = nil) async -> [UUID: [OpenHABItem]] {
        await Preferences.prepareForAppExtensionAccess()
        let targetHomes: [UUID] = if let homes {
            homes
        } else {
            await Preferences.shared.listStoredHomes()
        }
        var result: [UUID: [OpenHABItem]] = [:]

        for homeId in targetHomes {
            let sourceItems = items[homeId] ?? persistedItems(home: homeId)
            let filtered = sourceItems.ranked(searchTerm: searchTerm, for: types).map(\.item)
            if !filtered.isEmpty {
                result[homeId] = filtered
            }
        }

        return result
    }

    func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?, home: UUID) async -> [String] {
        await reloadCacheIfNeeded(homes: [home])
        return items[home]?
            .filtered(by: searchTerm, for: types)
            .map(\.name) ?? []
    }

    func getCachedItems(types: [OpenHABItem.ItemType]?, home: UUID) async -> [OpenHABItem] {
        await reloadCacheIfNeeded(homes: [home])
        return items[home]?
            .filtered(for: types)
            .sorted(by: \.name) ?? []
    }

    func searchItems(searchTerm: String, types: [OpenHABItem.ItemType]? = nil) async -> [UUID: [OpenHABItem]] {
        let allItems = await getAllCachedItems()
        var result: [UUID: [OpenHABItem]] = [:]

        for (homeId, homeItems) in allItems {
            let filtered = homeItems.ranked(searchTerm: searchTerm, for: types).map(\.item)
            if !filtered.isEmpty {
                result[homeId] = filtered
            }
        }

        return result
    }
}

public extension OpenHABItem {
    /// Checks if the item matches the specified types filter
    /// - Parameter types: Optional array of item types to match. If nil, all items match.
    /// - Returns: True if the item matches the filter, false otherwise
    func matches(types: [OpenHABItem.ItemType]?) -> Bool {
        types == nil || (type.flatMap { types?.contains($0) } == true)
    }

    func searchScore(for searchTerm: String, additionalCandidates: [String] = []) -> Int? {
        ItemSearchRanker.score(for: self, searchTerm: searchTerm, additionalCandidates: additionalCandidates)
    }
}

public extension [OpenHABItem] {
    func filtered(by searchTerm: String? = nil, for types: [OpenHABItem.ItemType]? = nil) -> [OpenHABItem] {
        ranked(searchTerm: searchTerm, for: types).map(\.item)
    }

    func ranked(searchTerm: String? = nil,
                for types: [OpenHABItem.ItemType]? = nil,
                additionalCandidates: (OpenHABItem) -> [String] = { _ in [] }) -> [(item: OpenHABItem, score: Int)] {
        compactMap { item in
            guard item.matches(types: types) else {
                return nil
            }

            guard let searchTerm, !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return (item: item, score: 0)
            }

            guard let score = item.searchScore(for: searchTerm, additionalCandidates: additionalCandidates(item)) else {
                return nil
            }

            return (item: item, score: score)
        }
        .sorted {
            if $0.score != $1.score {
                return $0.score < $1.score
            }

            return $0.item.name.localizedCaseInsensitiveCompare($1.item.name) == .orderedAscending
        }
    }
}
