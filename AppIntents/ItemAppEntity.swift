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
struct ItemAppEntity: AppEntity {
    struct ItemAppEntityQuery: EntityQuery {
        func entities(for identifiers: [ItemAppEntity.ID]) async throws -> [ItemAppEntity] {
            var result: [ItemAppEntity] = []

            for identifier in identifiers {
                if let items = await OpenHABItemCache.instance.getCachedItem(
                    name: identifier.itemName,
                    home: identifier.homeId
                ), let item = items.first {
                    result.append(ItemAppEntity(item, homeId: identifier.homeId))
                }
            }

            return result
        }

        func suggestedEntities() async throws -> [ItemAppEntity] {
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            var result: [ItemAppEntity] = []

            for (homeId, items) in allItems {
                let filteredItems = items.filter { $0.type == .switchItem }
                result.append(contentsOf: filteredItems.map { ItemAppEntity($0, homeId: homeId) })
            }

            return result
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item")
    static let typeDisplayName: LocalizedStringResource = "Item"

    static let defaultQuery = ItemAppEntityQuery()

    var id: ItemIdentifier
    var label: String
    var category: String
    var link: String
    var type: OpenHABItem.ItemType?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(label)", subtitle: "\(id.itemName)")
    }

    init(id: ItemIdentifier, label: String, category: String, link: String, type: OpenHABItem.ItemType?) {
        self.id = id
        self.label = label
        self.category = category
        self.link = link
        self.type = type
    }

    init(_ openHABItem: OpenHABItem, homeId: UUID) {
        self.init(
            id: ItemIdentifier(homeId: homeId, itemName: openHABItem.name),
            label: openHABItem.label,
            category: openHABItem.category,
            link: openHABItem.link,
            type: openHABItem.type
        )
    }
}

extension ItemIdentifier: EntityIdentifierConvertible {
    public var entityIdentifierString: String {
        "\(homeId.uuidString):\(itemName)"
    }

    public static func entityIdentifier(for entityIdentifierString: String) -> ItemIdentifier? {
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
}


//Usage Example in Your App Intents
//                                                                                                                                                                         
//struct ControlItemIntent: AppIntent {
//    @Parameter(title: "Item")
//    var item: ItemAppEntity
//                                                                                                                                                                         
//    func perform() async throws -> some IntentResult {
//        // Access components directly
//        await OpenHABItemCache.instance.sendCommand(
//            to: /* OpenHABItem */,
//            home: item.homeId,  // Clean access via computed property
//            command: "ON"
//        )
//        return .result()
//    }
//}
