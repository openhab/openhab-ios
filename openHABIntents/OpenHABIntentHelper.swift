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

import Foundation
import Intents
import OpenHABCore

@MainActor
public enum OpenHABIntentHelper {
    static func resolveHome(home: OpenHABHome?, item: String?) async -> OpenHABHomeResolutionResult {
        if let home, let homeId = home.uuid {
            // TODO: fuzzy matching / account for potential renaming?
            // TODO: accept potential mismatches if item name is unique
            let homePrefs = Preferences.shared.storedHomes.first { $0.key == homeId }
            if homePrefs != nil {
                return .success(with: home)
            }
            return .unsupported()
        }
        if let item {
            // try to find the home by home-specific item selection
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let homeIdsWithMatchingItems = allItems.map(\.key).filter { uuid in
                allItems[uuid]?.filtered(by: item).isEmpty != true
            }
            let potentialHomes = homeIdsWithMatchingItems
                .compactMap { Preferences.shared.storedHomes[$0] }
                .map { OpenHABHome(homeId: $0.id, homeName: $0.homeName) }
            if potentialHomes.count == 1 {
                return .success(with: potentialHomes[0])
            }
            return .disambiguation(with: potentialHomes)
        }
        return .needsValue()
    }

    static func getHomeOptions() -> INObjectCollection<OpenHABHome> {
        INObjectCollection(items: Preferences.shared.storedHomes.map { OpenHABHome(homeId: $0.value.id, homeName: $0.value.homeName) })
    }

    static func getItemOptions(home: OpenHABHome?, searchTerm: String? = nil, itemTypes: [OpenHABItem.ItemType]? = nil) async -> INObjectCollection<NSString> {
        let allItems = await getAllItems(home: home)
        let items = allItems.filtered(by: searchTerm, for: itemTypes)
        return INObjectCollection(items: items.map(\.name).map { $0 as NSString })
    }

    private static func getAllItems(home: OpenHABHome?) async -> [OpenHABItem] {
        if let home, let homeId = home.uuid {
            await OpenHABItemCache.instance.getCachedItems(home: homeId) ?? []
        } else {
            await OpenHABItemCache.instance.getAllCachedItems().flatMap(\.value)
        }
    }
}

extension OpenHABHome: @unchecked Sendable {
    var uuid: UUID? {
        UUID(uuidString: identifier ?? "")
    }

    convenience init(homeId: UUID, homeName: String) {
        self.init(identifier: homeId.uuidString, display: homeName)
    }
}

extension OpenHABHomeResolutionResult: @unchecked Sendable {}

extension INObjectCollection: @unchecked @retroactive Sendable {}
