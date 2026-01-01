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

// MARK: - Shared Protocol for All Item Entities

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
protocol ItemEntity: AppEntity where ID == ItemIdentifier {
    var id: ItemIdentifier { get set }
    var item: OpenHABItem { get set }
    var homeName: String? { get set }

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String?)
    init(_ openHABItem: OpenHABItem, homeId: UUID, homeName: String?)
}

// MARK: - Shared Implementation for All Item Entities

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
extension ItemEntity {
    var homeId: UUID { id.homeId }
    var itemName: String { id.itemName }

    // Convenient access to common item properties
    var label: String { item.label }
    var category: String { item.category }
    var type: OpenHABItem.ItemType? { item.type }
    var state: String? { item.state }
    var link: String { item.link }

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

    init(_ openHABItem: OpenHABItem, homeId: UUID, homeName: String? = nil) {
        self.init(
            id: ItemIdentifier(homeId: homeId, itemName: openHABItem.name),
            item: openHABItem,
            homeName: homeName
        )
    }
}

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
            types: allowedTypes
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

// MARK: - SwitchItemEntity

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SwitchItemEntity: ItemEntity {
    struct SwitchItemQuery: ItemEntityQuery {
        typealias EntityType = SwitchItemEntity

        @IntentParameterDependency<SwitchStateIntent>(\.$home)
        var intent

        var allowedTypes: [OpenHABItem.ItemType] = [.switchItem]
        var selectedHomeId: UUID? { UUID(uuidString: intent?.home.id ?? "") }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Switch Item")
    static let defaultQuery = SwitchItemQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }
}

// MARK: - DimmerItemEntity

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct DimmerItemEntity: ItemEntity {
    struct DimmerItemQuery: ItemEntityQuery {
        typealias EntityType = DimmerItemEntity

        @IntentParameterDependency<DimmerRollerValueIntent>(\.$home)
        var intent

        var allowedTypes: [OpenHABItem.ItemType] = [.dimmer, .rollershutter]
        var selectedHomeId: UUID? { UUID(uuidString: intent?.home.id ?? "") }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dimmer/Roller Item")
    static let defaultQuery = DimmerItemQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }
}

// MARK: - ColorItemEntity

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ColorItemEntity: ItemEntity {
    struct ColorItemQuery: ItemEntityQuery {
        typealias EntityType = ColorItemEntity

        @IntentParameterDependency<ColorValueIntent>(\.$home)
        var intent

        var allowedTypes: [OpenHABItem.ItemType] = [.color]
        var selectedHomeId: UUID? { UUID(uuidString: intent?.home.id ?? "") }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Color Item")
    static let defaultQuery = ColorItemQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }
}

// MARK: - NumberItemEntity

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct NumberItemEntity: ItemEntity {
    struct NumberItemQuery: ItemEntityQuery {
        typealias EntityType = NumberItemEntity

        @IntentParameterDependency<NumberValueIntent>(\.$home)
        var intent

        var allowedTypes: [OpenHABItem.ItemType] = [.number, .numberWithDimension]
        var selectedHomeId: UUID? { UUID(uuidString: intent?.home.id ?? "") }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Number Item")
    static let defaultQuery = NumberItemQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }
}

// MARK: - StringItemEntity

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct StringItemEntity: ItemEntity {
    struct StringItemQuery: ItemEntityQuery {
        typealias EntityType = StringItemEntity

        @IntentParameterDependency<StringValueIntent>(\.$home)
        var intent

        var allowedTypes: [OpenHABItem.ItemType] = [.stringItem]
        var selectedHomeId: UUID? { UUID(uuidString: intent?.home.id ?? "") }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "String Item")
    static let defaultQuery = StringItemQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }
}

// MARK: - ContactItemEntity

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ContactItemEntity: ItemEntity {
    struct ContactItemQuery: ItemEntityQuery {
        typealias EntityType = ContactItemEntity

        @IntentParameterDependency<ContactStateIntent>(\.$home)
        var intent

        var allowedTypes: [OpenHABItem.ItemType] = [.contact]
        var selectedHomeId: UUID? { UUID(uuidString: intent?.home.id ?? "") }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Contact Item")
    static let defaultQuery = ContactItemQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }
}

// MARK: - GenericItemEntity (for ItemStateIntent - all types)

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct GenericItemEntity: ItemEntity {
    struct GenericItemQuery: ItemEntityQuery {
        typealias EntityType = GenericItemEntity

        @IntentParameterDependency<ItemStateIntent>(\.$home)
        var intent

        var allowedTypes: [OpenHABItem.ItemType] = [] // Empty means all types
        var selectedHomeId: UUID? { UUID(uuidString: intent?.home.id ?? "") }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item")
    static let defaultQuery = GenericItemQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }
}
