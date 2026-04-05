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
    /// Returns a stable, cross-device identifier for a home that is the same on every device
    /// configured for the same openHAB server. Used as OpenHABHome.identifier so that shortcuts
    /// synced via iCloud can resolve the home on a different device.
    ///
    /// Priority:
    /// 1. cloudUserId — unique per myopenhab.org account
    /// 2. remote URL — unique for self-hosted servers
    /// 3. local URL — fallback for local-only setups
    /// 4. UUID string — last resort (no cross-device benefit, but avoids empty identifier)
    static func stableIdentifier(for homePrefs: HomePreferences) -> String {
        if let cloudId = homePrefs.remoteConnectionConfig.cloudUserId, !cloudId.isEmpty {
            return cloudId
        }
        if !homePrefs.remoteConnectionConfig.url.isEmpty {
            return homePrefs.remoteConnectionConfig.url
        }
        if !homePrefs.localConnectionConfig.url.isEmpty {
            return homePrefs.localConnectionConfig.url
        }
        return homePrefs.id.uuidString
    }

    /// Resolves the local home UUID for the given OpenHABHome.
    ///
    /// Supports both the current stable-identifier format and legacy shortcuts that stored a
    /// device-local UUID, so old shortcuts migrate automatically on first run.
    /// Returns `UUID?` (a `Sendable` type) so callers outside MainActor can use it safely.
    static func resolveHomeId(for home: OpenHABHome) -> UUID? {
        guard let identifier = home.identifier, !identifier.isEmpty else { return nil }
        let storedHomes = Preferences.shared.storedHomes

        // Current format: match by stable cross-device identifier
        if let match = storedHomes.values.first(where: { stableIdentifier(for: $0) == identifier }) {
            return match.id
        }

        // Legacy format: identifier is a device-local UUID string (shortcuts created before this fix)
        if let uuid = UUID(uuidString: identifier), storedHomes[uuid] != nil {
            return uuid
        }

        return nil
    }

    static func resolveHome(home: OpenHABHome?, item: String?) async -> OpenHABHomeResolutionResult {
        if let home {
            guard let homeId = resolveHomeId(for: home),
                  let homePrefs = Preferences.shared.storedHomes[homeId] else {
                return .unsupported()
            }
            // Return a fresh OpenHABHome with the stable identifier so Shortcuts updates
            // any legacy UUID-based shortcuts to the new format going forward.
            return .success(with: OpenHABHome(homePrefs: homePrefs))
        } else if let item {
            // try to find the home by home-specific item selection
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let homeIdsWithMatchingItems = allItems.map(\.key).filter { uuid in
                allItems[uuid]?.filtered(by: item).isEmpty != true
            }
            let potentialHomes = homeIdsWithMatchingItems
                .compactMap { Preferences.shared.storedHomes[$0] }
                .map { OpenHABHome(homePrefs: $0) }
            if potentialHomes.count == 1 {
                return .success(with: potentialHomes[0])
            } else {
                return .disambiguation(with: potentialHomes)
            }
        } else {
            return .needsValue()
        }
    }

    static func getHomeOptions() -> INObjectCollection<OpenHABHome> {
        INObjectCollection(items: Preferences.shared.storedHomes.map { OpenHABHome(homePrefs: $0.value) })
    }

    static func getItemOptions(home: OpenHABHome?, searchTerm: String? = nil, itemTypes: [OpenHABItem.ItemType]? = nil) async -> INObjectCollection<NSString> {
        let allItems = await getAllItems(home: home)
        let items = allItems.filtered(by: searchTerm, for: itemTypes)
        return INObjectCollection(items: items.map(\.name).map { $0 as NSString })
    }

    private static func getAllItems(home: OpenHABHome?) async -> [OpenHABItem] {
        if let home, let homeId = resolveHomeId(for: home) {
            await OpenHABItemCache.instance.getCachedItems(home: homeId) ?? []
        } else {
            await OpenHABItemCache.instance.getAllCachedItems().flatMap(\.value)
        }
    }
}

extension OpenHABHome: @unchecked Sendable {
    @MainActor
    convenience init(homePrefs: HomePreferences) {
        self.init(identifier: OpenHABIntentHelper.stableIdentifier(for: homePrefs), display: homePrefs.homeName)
    }
}

extension OpenHABHomeResolutionResult: @unchecked Sendable {}

extension INObjectCollection: @unchecked @retroactive Sendable {}
