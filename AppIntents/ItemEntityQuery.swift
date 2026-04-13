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

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
protocol ItemEntityQuery: EntityStringQuery {
    associatedtype EntityType: ItemEntity
    var allowedTypes: [OpenHABItem.ItemType] { get set }
    var selectedHomeId: UUID? { get }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension ItemEntityQuery {
    @MainActor
    func getHomeName(for homeId: UUID) -> String? {
        Preferences.shared.storedHomes[homeId]?.homeName
    }

    func entityResults(from itemsByHome: [UUID: [OpenHABItem]]) async -> [EntityType] {
        var result: [EntityType] = []

        for (homeId, items) in itemsByHome {
            let homeName = await getHomeName(for: homeId)
            result.append(contentsOf: items.map { EntityType($0, homeId: homeId, homeName: homeName) })
        }

        return result.sorted {
            if $0.item.name.localizedCaseInsensitiveCompare($1.item.name) != .orderedSame {
                return $0.item.name.localizedCaseInsensitiveCompare($1.item.name) == .orderedAscending
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
                item.name.localizedCaseInsensitiveCompare(normalizedSearchTerm) == .orderedSame ? (homeId, item) : nil
            }
        }

        guard matches.count == 1, let match = matches.first else {
            return nil
        }

        let homeName = await getHomeName(for: match.0)
        return EntityType(match.1, homeId: match.0, homeName: homeName)
    }

    func entities(for identifiers: [ItemIdentifier]) async throws -> [EntityType] {
        var result: [EntityType] = []

        for identifier in identifiers {
            if let item = await OpenHABItemCache.instance.getCachedOrPersistedItem(
                name: identifier.itemName,
                home: identifier.homeId
            ) {
                let homeName = await getHomeName(for: identifier.homeId)
                result.append(EntityType(item, homeId: identifier.homeId, homeName: homeName))
            }
        }

        return result
    }

    func suggestedEntities() async throws -> [EntityType] {
        // If the user selected a Home in the intent UI, scope results to that home.
        if let selectedHomeId {
            let itemsByHome = await OpenHABItemCache.instance.getCachedOrPersistedItems(
                types: allowedTypes.isEmpty ? nil : allowedTypes,
                homes: [selectedHomeId]
            )
            return await entityResults(from: itemsByHome)
        }

        // Fallback (e.g. Siri request without an explicit Home selection): return items across all homes.
        let storedHomes = await Preferences.shared.listStoredHomes()
        let itemsByHome = await OpenHABItemCache.instance.getCachedOrPersistedItems(
            types: allowedTypes.isEmpty ? nil : allowedTypes,
            homes: storedHomes
        )
        return await entityResults(from: itemsByHome)
    }

    func entities(matching string: String) async throws -> [EntityType] {
        let searchResults = await OpenHABItemCache.instance.searchCachedOrPersistedItems(
            searchTerm: string,
            types: allowedTypes.isEmpty ? nil : allowedTypes,
            homes: selectedHomeId.map { [$0] }
        )

        // If the user selected a Home in the intent UI, scope results to that home.
        if let selectedHomeId {
            return await entityResults(from: searchResults.filter { $0.key == selectedHomeId })
        }

        // If the typed item name resolves to exactly one item across all homes,
        // prefer that single result to avoid unnecessary cross-home ambiguity.
        if let uniqueExactMatch = await uniqueExactMatch(from: searchResults, searchTerm: string) {
            return [uniqueExactMatch]
        }

        // Fallback (e.g. Siri request without an explicit Home selection): return matches across all homes.
        return await entityResults(from: searchResults)
    }
}
