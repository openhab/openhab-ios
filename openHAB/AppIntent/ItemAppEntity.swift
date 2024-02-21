// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import os.log

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ItemAppEntity: AppEntity {
    struct ItemAppEntityQuery: EntityQuery {
        func entities(for identifiers: [ItemAppEntity.ID]) async throws -> [ItemAppEntity] {
            let items = await OpenHABItemCache.instance.getItems(types: [OpenHABItem.ItemType.switchItem]).filter { $0.name == identifiers.first }
            let result = items.map { item -> ItemAppEntity in
                ItemAppEntity(item)
            }
            return result
        }

        func entities(matching string: String) async throws -> [ItemAppEntity] {
            let items = await OpenHABItemCache.instance.getItems(types: [OpenHABItem.ItemType.switchItem]).filter { $0.name == string }
            let result = items.map { item -> ItemAppEntity in
                ItemAppEntity(item)
            }
            return result
        }

        func entities(matching string: String) async throws -> IntentItemCollection<ItemAppEntity> {
            let items = await OpenHABItemCache.instance.getItems(types: [OpenHABItem.ItemType.switchItem]).filter { $0.name == string }
            return ItemCollection {
                ItemSection<ItemAppEntity>(
                    "Regulars",
                    items:
                    items.map {
                        IntentItem<ItemAppEntity>(
                            ItemAppEntity($0),
                            title: LocalizedStringResource(stringLiteral: ItemAppEntity($0).label),
                            image: ItemAppEntity($0).displayRepresentation.image
                        )
                    }
                )
            }
        }

        func suggestedEntities() async throws -> [ItemAppEntity] {
            let items = await OpenHABItemCache.instance.getItems(types: [OpenHABItem.ItemType.switchItem])
            let result = items.map { item -> ItemAppEntity in
                ItemAppEntity(item)
            }
            return result
        }

        /// - Tag: suggestedEntities
//        func suggestedEntities() async throws -> IntentItemCollection<ItemAppEntity> {
//            let items = await OpenHABItemCache.instance.getItems(types: [OpenHABItem.ItemType.switchItem])
//            return ItemCollection {
//                ItemSection<ItemAppEntity>(
//                    items:
//                    items.map {
//                        IntentItem<ItemAppEntity>(
//                            ItemAppEntity($0),
//                            title: LocalizedStringResource(stringLiteral: ItemAppEntity($0).displayString),
//                            image: ItemAppEntity($0).displayRepresentation.image
//                        )
//                    }
//                )
//            }
//        }
    }

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item")
    static var typeDisplayName: LocalizedStringResource = "Item"

    static var defaultQuery = ItemAppEntityQuery()

    var id: String // if your identifier is not a String, conform the entity to EntityIdentifierConvertible.
    var label: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)", subtitle: "\(label)")
    }

    init(id: String, label: String, category: String, link: String, type: OpenHABItem.ItemType?) {
        self.id = id
        self.label = label
    }

    init(_ openHABItem: OpenHABItem) {
        self.init(
            id: openHABItem.name,
            label: openHABItem.label,
            category: openHABItem.category,
            link: openHABItem.link,
            type: openHABItem.type
        )
    }
}
