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

// MARK: - Shared Protocol for All Item Entities

protocol ItemEntity: AppEntity where ID == ItemIdentifier {
    var id: ItemIdentifier { get set }
    var item: OpenHABItem { get set }
    var homeName: String? { get set }

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String?)
    init(_ openHABItem: OpenHABItem, homeId: UUID, homeName: String?)
}

extension ItemEntity {
    var homeId: UUID? {
        id.homeId
    }

    var itemName: String {
        id.itemName
    }

    /// Convenient access to common item properties
    var label: String {
        item.label
    }

    var category: String {
        item.category
    }

    var type: OpenHABItem.ItemType? {
        item.type
    }

    var state: String? {
        item.state
    }

    var link: String {
        item.link
    }

    var displayRepresentation: DisplayRepresentation {
        if let homeName {
            DisplayRepresentation(
                title: "\(label)",
                subtitle: "\(item.name) • \(homeName)"
            )
        } else {
            DisplayRepresentation(
                title: "\(label)",
                subtitle: "\(item.name)"
            )
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
