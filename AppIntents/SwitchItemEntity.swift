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

// MARK: - DimmerItemEntity

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct DimmerItemEntity: ItemEntity {
    struct DimmerItemQuery: ItemEntityQuery {
        typealias EntityType = DimmerItemEntity

        @IntentParameterDependency<SetDimmerRollerValueIntent>(\.$home)
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

        @IntentParameterDependency<SetColorValueIntent>(\.$home)
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

        @IntentParameterDependency<SetNumberValueIntent>(\.$home)
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

        @IntentParameterDependency<SetStringValueIntent>(\.$home)
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

        @IntentParameterDependency<GetItemStateIntent>(\.$home)
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

// MARK: - SwitchItemEntity

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SwitchItemEntity: ItemEntity {
    struct SwitchItemQuery: ItemEntityQuery {
        typealias EntityType = SwitchItemEntity

        @IntentParameterDependency<SetSwitchItemIntent>(\.$home)
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
