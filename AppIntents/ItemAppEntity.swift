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

import AppIntents
import Intents
import OpenHABCore

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ItemAppEntity: AppEntity, Identifiable {
    struct ItemAppEntityQuery: EntityStringQuery {
        @IntentParameterDependency<SwitchStateIntent>(\.$home)
        var intent

        func entities(for identifiers: [ItemAppEntity.ID]) async throws -> [ItemAppEntity] {
            var result: [ItemAppEntity] = []

            for identifier in identifiers {
                if let items = await OpenHABItemCache.instance.getCachedItem(
                    name: identifier.itemName,
                    home: identifier.homeId
                ), let item = items.first {
                    let homeName = await getHomeName(for: identifier.homeId)
                    result.append(ItemAppEntity(item, homeId: identifier.homeId, homeName: homeName))
                }
            }

            return result
        }

        @MainActor
        private func getHomeName(for homeId: UUID) -> String? {
            Preferences.shared.storedHomes[homeId]?.homeName
        }

        func suggestedEntities() async throws -> [ItemAppEntity] {
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            var result: [ItemAppEntity] = []

            // If the user selected a Home in the intent UI, scope results to that home.
            if let selectedHome = intent?.home,
               let selectedHomeId = UUID(uuidString: selectedHome.id) {
                if let items = allItems[selectedHomeId] {
                    let homeName = await getHomeName(for: selectedHomeId)
                    let filteredItems = items.filter { $0.type == .switchItem }
                    result.append(contentsOf: filteredItems.map { ItemAppEntity($0, homeId: selectedHomeId, homeName: homeName) })
                }
                return result
            }

            // Fallback (e.g. Siri request without an explicit Home selection): return items across all homes.
            for (homeId, items) in allItems {
                let homeName = await getHomeName(for: homeId)
                let filteredItems = items.filter { $0.type == .switchItem }
                result.append(contentsOf: filteredItems.map { ItemAppEntity($0, homeId: homeId, homeName: homeName) })
            }

            return result
        }

        func entities(matching string: String) async throws -> [ItemAppEntity] {
            let searchResults = await OpenHABItemCache.instance.searchItems(
                searchTerm: string,
                types: [.switchItem]
            )
            var result: [ItemAppEntity] = []

            // If the user selected a Home in the intent UI, scope results to that home.
            if let selectedHome = intent?.home,
               let selectedHomeId = UUID(uuidString: selectedHome.id) {
                if let items = searchResults[selectedHomeId] {
                    let homeName = await getHomeName(for: selectedHomeId)
                    result.append(contentsOf: items.map { ItemAppEntity($0, homeId: selectedHomeId, homeName: homeName) })
                }
                return result
            }

            // Fallback (e.g. Siri request without an explicit Home selection): return matches across all homes.
            for (homeId, items) in searchResults {
                let homeName = await getHomeName(for: homeId)
                result.append(contentsOf: items.map { ItemAppEntity($0, homeId: homeId, homeName: homeName) })
            }

            return result
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item")
    static let typeDisplayName: LocalizedStringResource = "Item"

    static let defaultQuery = ItemAppEntityQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    var displayRepresentation: DisplayRepresentation {
        if let homeName {
            DisplayRepresentation(
                title: "\(label)",
                subtitle: "\(item.name) • \(homeName)"
            )
        } else {
            DisplayRepresentation(title: "\(label)", subtitle: "\(item.name)")
        }
    }

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }

    init(_ openHABItem: OpenHABItem, homeId: UUID, homeName: String? = nil) {
        self.init(
            id: ItemIdentifier(homeId: homeId, itemName: openHABItem.name),
            item: openHABItem,
            homeName: homeName
        )
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension ItemAppEntity {
    var homeId: UUID { id.homeId }
    var itemName: String { id.itemName }

    // Convenient access to common item properties
    var label: String { item.label }
    var category: String { item.category }
    var type: OpenHABItem.ItemType? { item.type }
    var state: String? { item.state }
    var link: String { item.link }
}
