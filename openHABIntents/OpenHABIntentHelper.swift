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

import Foundation
import Intents
import OpenHABCore
import os

public enum OpenHABIntentHelper {
    static func resolveHome(home: OpenHABHome?, item: String?) async -> OpenHABHomeResolutionResult {
        if let home, let homeId = home.uuid {
            // TODO: fuzzy matching / account for potential renaming?
            // TODO: accept potential mismatches if item name is unique
            let storedHomes = await Preferences.shared.storedHomes
            let homePrefs = storedHomes.first { $0.key == homeId }
            if homePrefs != nil {
                return .success(with: home)
            } else {
                // Fallback to first available home if requested home doesn't exist
                Logger.intentHandling.warning("Home \(homeId) not found for resolveHome. Available homes: \(storedHomes.keys)")
                guard let resolvedHomeId = await resolveHomeId(homeId),
                      let homeValue = storedHomes[resolvedHomeId] else {
                    return .unsupported()
                }
                let fallbackHome = await OpenHABHome(homeId: homeValue.id, homeName: homeValue.homeName)
                return .success(with: fallbackHome)
            }
        } else if let item {
            // try to find the home by home-specific item selection
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let homeIdsWithMatchingItems = allItems.map(\.key).filter { uuid in
                allItems[uuid]?.filtered(by: item).isEmpty != true
            }
            let storedHomes = await Preferences.shared.storedHomes
            var potentialHomes: [OpenHABHome] = []
            await MainActor.run {
                potentialHomes = homeIdsWithMatchingItems
                    .compactMap { storedHomes[$0] }
                    .map { OpenHABHome(homeId: $0.id, homeName: $0.homeName) }
            }
            if potentialHomes.count == 1 {
                return .success(with: potentialHomes[0])
            } else {
                return .disambiguation(with: potentialHomes)
            }
        } else {
            return .needsValue()
        }
    }

    static func getHomeOptions() async -> INObjectCollection<OpenHABHome> {
        let storedHomes = await Preferences.shared.storedHomes
        return await MainActor.run {
            INObjectCollection(items: storedHomes.map { OpenHABHome(homeId: $0.value.id, homeName: $0.value.homeName) })
        }
    }

    static func getItemOptions(home: OpenHABHome?, searchTerm: String? = nil, itemTypes: [OpenHABItem.ItemType]? = nil) async -> INObjectCollection<NSString> {
        Logger.intentHandling.info("getItemOptions called with home: \(home?.identifier ?? "nil"), searchTerm: \(searchTerm ?? "nil")")
        let allItems = await getAllItems(home: home)
        Logger.intentHandling.info("getAllItems returned \(allItems.count) items")
        let items = allItems.filtered(by: searchTerm, for: itemTypes)
        Logger.intentHandling.info("After filtering: \(items.count) items")
        return INObjectCollection(items: items.map(\.name).map { $0 as NSString })
    }

    private static func getAllItems(home: OpenHABHome?) async -> [OpenHABItem] {
        if let home, let homeId = home.uuid {
            Logger.intentHandling.info("Getting cached items for specific home: \(homeId)")

            // Validate home exists before trying to load and fallback to first available home if needed
            guard let actualHomeId = await resolveHomeId(homeId) else {
                return []
            }

            let items = await OpenHABItemCache.instance.getCachedItems(home: actualHomeId) ?? []
            Logger.intentHandling.info("Found \(items.count) items for home \(actualHomeId)")

            // If no items found, try to reload the cache once
            if items.isEmpty {
                Logger.intentHandling.info("No items found, forcing cache reload for home \(actualHomeId)")
                await OpenHABItemCache.instance.forceCacheReload(homes: [actualHomeId])
                let reloadedItems = await OpenHABItemCache.instance.getCachedItems(home: actualHomeId) ?? []
                Logger.intentHandling.info("After reload: Found \(reloadedItems.count) items for home \(actualHomeId)")
                return reloadedItems
            }

            return items
        } else {
            Logger.intentHandling.info("Getting all cached items from all homes")
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            Logger.intentHandling.info("All cached items: \(allItems.map { ($0.key, $0.value.count) })")
            let flatItems = allItems.flatMap(\.value)
            Logger.intentHandling.info("Total flattened items: \(flatItems.count)")

            // If no items found, try to reload the cache once
            if flatItems.isEmpty {
                Logger.intentHandling.info("No items found, forcing full cache reload")
                await OpenHABItemCache.instance.forceCacheReload()
                let reloadedAllItems = await OpenHABItemCache.instance.getAllCachedItems()
                Logger.intentHandling.info("After reload: All cached items: \(reloadedAllItems.map { ($0.key, $0.value.count) })")
                let reloadedFlatItems = reloadedAllItems.flatMap(\.value)
                Logger.intentHandling.info("After reload: Total flattened items: \(reloadedFlatItems.count)")
                return reloadedFlatItems
            }

            return flatItems
        }
    }

    /// Resolves a home ID with fallback logic for deleted homes.
    /// If the requested home exists, returns it. Otherwise, falls back to the first available home (sorted by UUID).
    /// - Parameter homeId: The requested home UUID
    /// - Returns: The resolved home UUID, or nil if no homes are available
    static func resolveHomeId(_ homeId: UUID) async -> UUID? {
        let storedHomes = await Preferences.shared.storedHomes

        // If requested home exists, return it
        if storedHomes[homeId] != nil {
            return homeId
        }

        // Fallback to first available home (sorted for deterministic behavior)
        Logger.intentHandling.warning("Home \(homeId) not found in handle. Falling back to first available home")
        guard let firstHome = storedHomes.keys.sorted(by: { $0.uuidString < $1.uuidString }).first else {
            Logger.intentHandling.error("No homes available at all!")
            return nil
        }

        Logger.intentHandling.info("Falling back to first available home: \(firstHome)")
        return firstHome
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
