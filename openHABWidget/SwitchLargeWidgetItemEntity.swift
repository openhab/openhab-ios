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

struct SwitchLargeWidgetItemEntity: ItemEntity {
    struct SwitchLargeWidgetItemQuery: ItemEntityQuery {
        typealias EntityType = SwitchLargeWidgetItemEntity

        @IntentParameterDependency<SwitchLargeConfigurationAppIntent>(\.$home)
        var intent

        var allowedTypes: [OpenHABItem.ItemType] = [.switchItem]
        var selectedHome: Home? {
            intent?.home
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Switch Item")
    static let defaultQuery = SwitchLargeWidgetItemQuery()

    var id: ItemIdentifier
    var item: OpenHABItem
    var homeName: String?

    init(id: ItemIdentifier, item: OpenHABItem, homeName: String? = nil) {
        self.id = id
        self.item = item
        self.homeName = homeName
    }
}
