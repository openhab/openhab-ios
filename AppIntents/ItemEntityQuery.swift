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

import AppIntents
import OpenHABCore

// MARK: - Shared Query Protocol

protocol ItemEntityQuery: EntityStringQuery {
    associatedtype EntityType: ItemEntity

    var allowedTypes: [OpenHABItem.ItemType] { get }
    var selectedHome: Home? { get }
}

extension ItemEntityQuery {
    func getHomeName(for homeId: UUID) async -> String? {
        await Preferences.shared.storedHomes[homeId]?.homeName
    }

    func getHomeIdentifier(for homeId: UUID) async -> String {
        let storedHomes = await Preferences.shared.storedHomes
        guard let home = storedHomes[homeId] else {
            return homeId.uuidString
        }
        return "\(home.stableIdentifier)##\(home.id.uuidString)"
    }

    func resolvedSelectedHomeId() async -> UUID? {
        guard let home = selectedHome else { return nil }
        let storedHomes = await Preferences.shared.storedHomes
        let homeId = home.id
        return await MainActor.run { Home.resolveStoredHomeKey(for: homeId, in: storedHomes) }
    }

    func resolvedHomeId(for identifier: ItemIdentifier) async -> UUID? {
        let storedHomes = await Preferences.shared.storedHomes
        guard let homeIdentifier = identifier.homeIdentifier else {
            guard let homeId = identifier.homeId, storedHomes[homeId] != nil else { return nil }
            return homeId
        }
        return await MainActor.run { Home.resolveStoredHomeKey(for: homeIdentifier, in: storedHomes) }
    }

    func entity(for item: OpenHABItem, homeId: UUID) async -> EntityType {
        let homeName = await getHomeName(for: homeId)
        let homeIdentifier = await getHomeIdentifier(for: homeId)
        return EntityType(
            id: ItemIdentifier(homeId: homeId, itemName: item.name, homeIdentifier: homeIdentifier),
            item: item,
            homeName: homeName
        )
    }

    func entityResults(from itemsByHome: [UUID: [OpenHABItem]]) async -> [EntityType] {
        var result: [EntityType] = []

        for (homeId, items) in itemsByHome {
            for item in items {
                let entity = await entity(for: item, homeId: homeId)
                result.append(entity)
            }
        }

        return result.sorted {
            let nameOrder = $0.item.name.localizedCaseInsensitiveCompare($1.item.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            let leftHomeName = $0.homeName ?? ""
            let rightHomeName = $1.homeName ?? ""
            return leftHomeName.localizedCaseInsensitiveCompare(rightHomeName) == .orderedAscending
        }
    }

    func uniqueExactMatch(from itemsByHome: [UUID: [OpenHABItem]], searchTerm: String) async -> EntityType? {
        let normalizedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSearchTerm.isEmpty else {
            return nil
        }

        let matches = itemsByHome.flatMap { homeId, items in
            items.compactMap { item in
                isExactMatch(item, searchTerm: normalizedSearchTerm) ? (homeId, item) : nil
            }
        }

        guard matches.count == 1, let match = matches.first else {
            return nil
        }

        return await entity(for: match.1, homeId: match.0)
    }

    func entities(for identifiers: [ItemIdentifier]) async throws -> [EntityType] {
        await Preferences.prepareForAppExtensionAccess()

        // Resolve each identifier to its cache key (storedHomes dict key).
        // The cache key may differ from identifier.homeId when there is a key/id mismatch in
        // stored data — the cache is always keyed by the dict key, not HomePreferences.id.
        var resolved: [(identifier: ItemIdentifier, cacheKey: UUID)] = []
        for identifier in identifiers {
            if let cacheKey = await resolvedHomeId(for: identifier) {
                resolved.append((identifier, cacheKey))
            }
        }

        let uniqueCacheKeys = Array(Set(resolved.map(\.cacheKey)))
        await OpenHABItemCache.instance.reloadCacheIfNeeded(homes: uniqueCacheKeys)

        var result: [EntityType] = []
        for (identifier, cacheKey) in resolved {
            let homeName = await getHomeName(for: cacheKey)
            // Use the cached/persisted item if available for its label, type, and state.
            // If not found (cold cache, item not yet indexed), fall back to a skeleton built
            // from the identifier so perform() can still execute — it only needs item.name.
            // This avoids Shortcuts re-prompting for the item just because the cache is cold.
            let item = await OpenHABItemCache.instance.getCachedOrPersistedItem(
                name: identifier.itemName,
                home: cacheKey
            ) ?? OpenHABItem(
                name: identifier.itemName,
                type: "",
                state: nil,
                link: "",
                label: identifier.itemName,
                groupType: nil,
                stateDescription: nil,
                commandDescription: nil,
                members: [],
                category: nil,
                options: nil
            )
            // Use cacheKey (current-device dict key) as homeId so perform() receives a UUID
            // that assureNetworkTracker can resolve on this device.
            result.append(EntityType(
                id: ItemIdentifier(homeId: cacheKey, itemName: item.name, homeIdentifier: identifier.homeIdentifier),
                item: item,
                homeName: homeName
            ))
        }

        return result
    }

    func suggestedEntities() async throws -> [EntityType] {
        await Preferences.prepareForAppExtensionAccess()

        // If the user selected a Home in the intent UI, scope results to that home.
        if let selectedHomeId = await resolvedSelectedHomeId() {
            await OpenHABItemCache.instance.reloadCacheIfNeeded(homes: [selectedHomeId])
            let itemsByHome = await OpenHABItemCache.instance.getCachedOrPersistedItems(
                types: allowedTypes.isEmpty ? nil : allowedTypes,
                homes: [selectedHomeId]
            )
            return await entityResults(from: itemsByHome)
        }

        // Fallback (e.g. Siri request without an explicit Home selection): return items across all homes.
        let storedHomes = await Preferences.shared.listStoredHomes()
        await OpenHABItemCache.instance.reloadCacheIfNeeded(homes: storedHomes)
        let itemsByHome = await OpenHABItemCache.instance.getCachedOrPersistedItems(
            types: allowedTypes.isEmpty ? nil : allowedTypes,
            homes: storedHomes
        )
        return await entityResults(from: itemsByHome)
    }

    func entities(matching string: String) async throws -> [EntityType] {
        await Preferences.prepareForAppExtensionAccess()

        let selectedHomeId = await resolvedSelectedHomeId()
        let searchResults: [UUID: [OpenHABItem]]
        if let selectedHomeId {
            await OpenHABItemCache.instance.reloadCacheIfNeeded(homes: [selectedHomeId])
            searchResults = await OpenHABItemCache.instance.searchCachedOrPersistedItems(
                searchTerm: string,
                types: allowedTypes.isEmpty ? nil : allowedTypes,
                homes: [selectedHomeId]
            )
        } else {
            let storedHomes = await Preferences.shared.listStoredHomes()
            await OpenHABItemCache.instance.reloadCacheIfNeeded(homes: storedHomes)
            let homeNames = await homeNames(for: storedHomes)
            searchResults = await homeAwareSearchResults(
                matching: string,
                types: allowedTypes.isEmpty ? nil : allowedTypes,
                homes: storedHomes,
                homeNames: homeNames
            )
        }

        // If the user selected a Home in the intent UI, scope results to that home.
        if selectedHomeId != nil {
            return await entityResults(from: searchResults)
        }

        // If the typed item name resolves to exactly one item across all homes,
        // prefer that single result to avoid unnecessary cross-home ambiguity.
        if let uniqueExactMatch = await uniqueExactMatch(from: searchResults, searchTerm: string) {
            return [uniqueExactMatch]
        }

        // Fallback (e.g. Siri request without an explicit Home selection): return matches across all homes.
        return await entityResults(from: searchResults)
    }

    func isExactMatch(_ item: OpenHABItem, searchTerm: String) -> Bool {
        let hasExactNameMatch = item.name.localizedCaseInsensitiveCompare(searchTerm) == .orderedSame
        let hasExactLabelMatch = item.label.localizedCaseInsensitiveCompare(searchTerm) == .orderedSame
        return hasExactNameMatch || hasExactLabelMatch
    }

    func homeNames(for homeIds: [UUID]) async -> [UUID: String] {
        let storedHomes = await Preferences.shared.storedHomes
        return Dictionary(uniqueKeysWithValues: homeIds.compactMap { homeId in
            storedHomes[homeId].map { (homeId, $0.homeName) }
        })
    }

    func homeAwareSearchResults(matching string: String,
                                types: [OpenHABItem.ItemType]?,
                                homes: [UUID],
                                homeNames: [UUID: String]) async -> [UUID: [OpenHABItem]] {
        let itemsByHome = await OpenHABItemCache.instance.getCachedOrPersistedItems(types: types, homes: homes)
        var result: [UUID: [OpenHABItem]] = [:]

        for homeId in homes {
            let homeName = homeNames[homeId]
            let filtered = (itemsByHome[homeId] ?? [])
                .ranked(searchTerm: string, for: types) { item in
                    guard let homeName else {
                        return []
                    }
                    return [
                        homeName,
                        "\(item.name) \(homeName)",
                        "\(item.label) \(homeName)"
                    ]
                }
                .map(\.item)

            if !filtered.isEmpty {
                result[homeId] = filtered
            }
        }

        return result
    }
}
