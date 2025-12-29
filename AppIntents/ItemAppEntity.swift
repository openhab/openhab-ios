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

struct ItemIdentifier: Hashable, Codable {
    let homeId: UUID
    let itemName: String
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ItemAppEntity: AppEntity, Hashable {
    struct ItemAppEntityQuery: EntityQuery {
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

    // Hashable conformance - hash based on id only
    static func == (lhs: ItemAppEntity, rhs: ItemAppEntity) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ItemIdentifier: EntityIdentifierConvertible {
    var entityIdentifierString: String {
        "\(homeId.uuidString):\(itemName)"
    }

    static func entityIdentifier(for entityIdentifierString: String) -> ItemIdentifier? {
        let components = entityIdentifierString.split(separator: ":", maxSplits: 1)
        guard components.count == 2,
              let homeId = UUID(uuidString: String(components[0])) else {
            return nil
        }
        return ItemIdentifier(homeId: homeId, itemName: String(components[1]))
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

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ControlItemIntent: AppIntent {
    struct ActionOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            [
                String(localized: "on").capitalized,
                String(localized: "off").capitalized
            ]
        }
    }

    static let title: LocalizedStringResource = "Control Item"

    @Parameter(title: "Home")
    var home: Home

    @Parameter(title: "Item")
    var itemEntity: ItemAppEntity

    @Parameter(title: "Action", optionsProvider: ActionOptionsProvider())
    var action: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$itemEntity)") {
            \.$home
        }
    }

    func perform() async throws -> some IntentResult {
        // Validate that the item belongs to the selected home
        guard let homeId = UUID(uuidString: home.id), homeId == itemEntity.homeId else {
            throw ControlItemError.itemNotInHome(itemEntity.label, home.displayString)
        }

        let onLabel = String(localized: "on").capitalized
        let offLabel = String(localized: "off").capitalized
        let actionMap: [String: String] = [
            onLabel: "ON",
            offLabel: "OFF"
        ]

        guard let command = actionMap[action] else {
            throw ControlItemError.invalidAction(action, itemEntity.label)
        }

        await OpenHABItemCache.instance.sendCommand(
            to: itemEntity.item,
            home: itemEntity.homeId,
            command: command
        )

        return .result()
    }
}

enum ControlItemError: Error, CustomLocalizedStringResourceConvertible {
    case invalidAction(String, String)
    case itemNotInHome(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .invalidAction(action, itemName):
            "Action invalid: \(action) for \(itemName)"
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        }
    }
}
