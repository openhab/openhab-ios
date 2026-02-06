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

    func entities(for identifiers: [ItemIdentifier]) async throws -> [EntityType] {
        var result: [EntityType] = []

        for identifier in identifiers {
            if let items = await OpenHABItemCache.instance.getCachedItem(
                name: identifier.itemName,
                home: identifier.homeId
            ), let item = items.first {
                let homeName = await getHomeName(for: identifier.homeId)
                result.append(EntityType(item, homeId: identifier.homeId, homeName: homeName))
            }
        }

        return result
    }

    func suggestedEntities() async throws -> [EntityType] {
        let allItems = await OpenHABItemCache.instance.getAllCachedItems()
        var result: [EntityType] = []

        // If the user selected a Home in the intent UI, scope results to that home.
        if let selectedHomeId {
            if let items = allItems[selectedHomeId] {
                let homeName = await getHomeName(for: selectedHomeId)
                let filteredItems = items.filter { item in
                    guard let type = item.type else { return false }
                    return allowedTypes.isEmpty || allowedTypes.contains(type)
                }
                result.append(contentsOf: filteredItems.map { EntityType($0, homeId: selectedHomeId, homeName: homeName) })
            }
            return result
        }

        // Fallback (e.g. Siri request without an explicit Home selection): return items across all homes.
        for (homeId, items) in allItems {
            let homeName = await getHomeName(for: homeId)
            let filteredItems = items.filter { item in
                guard let type = item.type else { return false }
                return allowedTypes.isEmpty || allowedTypes.contains(type)
            }
            result.append(contentsOf: filteredItems.map { EntityType($0, homeId: homeId, homeName: homeName) })
        }

        return result
    }

    func entities(matching string: String) async throws -> [EntityType] {
        let searchResults = await OpenHABItemCache.instance.searchItems(
            searchTerm: string,
            types: allowedTypes.isEmpty ? nil : allowedTypes
        )
        var result: [EntityType] = []

        // If the user selected a Home in the intent UI, scope results to that home.
        if let selectedHomeId {
            if let items = searchResults[selectedHomeId] {
                let homeName = await getHomeName(for: selectedHomeId)
                result.append(contentsOf: items.map { EntityType($0, homeId: selectedHomeId, homeName: homeName) })
            }
            return result
        }

        // Fallback (e.g. Siri request without an explicit Home selection): return matches across all homes.
        for (homeId, items) in searchResults {
            let homeName = await getHomeName(for: homeId)
            result.append(contentsOf: items.map { EntityType($0, homeId: homeId, homeName: homeName) })
        }

        return result
    }
}
