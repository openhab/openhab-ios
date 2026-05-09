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
import Foundation
import OpenHABCore

// MARK: - Errors

enum HomeResolutionError: Error, CustomLocalizedStringResourceConvertible {
    case unknownHome
    case ambiguousHomeSelection(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unknownHome:
            "Unknown home"
        case let .ambiguousHomeSelection(itemName):
            "Select a home for '\(itemName)'"
        }
    }
}

// MARK: - HomeResolver

enum HomeResolver {
    /// Validates that `selectedHome` matches `itemHomeId` and returns the resolved local UUID.
    ///
    /// Resolution order:
    /// 1. Match `selectedHome.id` against entries in `stableIdentifierToLocalUUID`.
    /// 2. Fall back to treating `selectedHome.id` as a legacy device-local UUID string.
    ///
    /// The default empty array skips stable-identifier lookup and falls straight through to the
    /// UUID fallback — this keeps unit tests working without any Preferences setup.
    static func resolvedHomeId(selectedHome: Home?,
                               itemHomeId: UUID,
                               itemLabel: String,
                               stableIdentifierToLocalUUID: [(String, UUID)] = [],
                               mismatchError: (String, String) -> some Error) throws -> UUID {
        guard let selectedHome else {
            return itemHomeId
        }

        let homeId: UUID
        if let match = stableIdentifierToLocalUUID.first(where: { $0.0 == selectedHome.id }) {
            homeId = match.1
        } else if let uuid = UUID(uuidString: selectedHome.id) {
            homeId = uuid
        } else {
            throw HomeResolutionError.unknownHome
        }

        guard homeId == itemHomeId else {
            throw mismatchError(itemLabel, selectedHome.displayString)
        }

        return homeId
    }

    /// Production overload — builds the stable-identifier map on the main actor before delegating
    /// to the testable sync overload. Intent `perform()` methods call this with `try await`.
    @MainActor
    static func resolvedHomeId(selectedHome: Home?,
                               itemHomeId: UUID,
                               itemLabel: String,
                               mismatchError: (String, String) -> some Error) throws -> UUID {
        let map = Preferences.shared.storedHomes.values.map { ($0.stableIdentifier, $0.id) }
        return try resolvedHomeId(
            selectedHome: selectedHome,
            itemHomeId: itemHomeId,
            itemLabel: itemLabel,
            stableIdentifierToLocalUUID: map,
            mismatchError: mismatchError
        )
    }

    /// Production overload for item-by-name resolution (iOS 16 compat intents).
    /// Builds a stable-identifier-aware `findHomeId` closure and delegates to the testable overload.
    static func resolveHomeId(selectedHome: Home?,
                              itemName: String,
                              allowedTypes: [OpenHABItem.ItemType]? = nil) async throws -> UUID {
        try await resolveHomeId(
            selectedHome: selectedHome,
            itemName: itemName,
            findHomeId: { identifier in
                // All HomePreferences property access must happen on the main actor.
                await MainActor.run {
                    let storedHomes = Preferences.shared.storedHomes
                    if let match = storedHomes.values.first(where: { $0.stableIdentifier == identifier }) {
                        return match.id
                    }
                    if let uuid = UUID(uuidString: identifier), storedHomes[uuid] != nil {
                        return uuid
                    }
                    return nil
                }
            },
            listStoredHomes: { await Preferences.shared.listStoredHomes() },
            exactMatchedHomes: {
                let searchResults = await OpenHABItemCache.instance.searchCachedOrPersistedItems(
                    searchTerm: itemName,
                    types: allowedTypes
                )
                let normalizedItemName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)

                return Set(searchResults.flatMap { homeId, items in
                    items.compactMap { item in
                        item.name.localizedCaseInsensitiveCompare(normalizedItemName) == .orderedSame ? homeId : nil
                    }
                })
            }
        )
    }

    /// Testable overload. All parameters are injected via closures so unit tests can provide
    /// mock implementations.
    ///
    /// `findHomeId` defaults to UUID-string parsing so existing tests that only exercise the
    /// `selectedHome: nil` path compile and run without modification.
    static func resolveHomeId(selectedHome: Home?,
                              itemName: String,
                              findHomeId: @escaping (String) async -> UUID? = { UUID(uuidString: $0) },
                              listStoredHomes: @escaping () async -> [UUID],
                              exactMatchedHomes: @escaping () async -> Set<UUID>) async throws -> UUID {
        if let selectedHome {
            guard let homeId = await findHomeId(selectedHome.id) else {
                throw HomeResolutionError.unknownHome
            }
            return homeId
        }

        let storedHomes = await listStoredHomes()
        if storedHomes.count == 1, let onlyHomeId = storedHomes.first {
            return onlyHomeId
        }

        let matchedHomes = await exactMatchedHomes()
        if matchedHomes.count == 1, let matchedHomeId = matchedHomes.first {
            return matchedHomeId
        }

        throw HomeResolutionError.ambiguousHomeSelection(itemName)
    }
}

// MARK: - Home AppEntity

struct Home: AppEntity {
    struct HomeQuery: EntityQuery {
        @MainActor
        func entities(for identifiers: [Home.ID]) throws -> [Home] {
            let storedHomes = Preferences.shared.storedHomes
            return identifiers.compactMap { identifier in
                // Current format: match by stable cross-device identifier
                if let match = storedHomes.values.first(where: { $0.stableIdentifier == identifier }) {
                    return Home(homePrefs: match)
                }
                // Legacy format: identifier is a device-local UUID string (shortcuts before this fix)
                if let uuid = UUID(uuidString: identifier), let match = storedHomes[uuid] {
                    return Home(homePrefs: match)
                }
                return nil
            }
        }

        @MainActor
        func suggestedEntities() throws -> [Home] {
            Preferences.shared.storedHomes.values
                .sorted {
                    let nameOrder = $0.homeName.localizedCaseInsensitiveCompare($1.homeName)
                    if nameOrder != .orderedSame {
                        return nameOrder == .orderedAscending
                    }
                    return $0.id.uuidString < $1.id.uuidString
                }
                .map { Home(homePrefs: $0) }
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Home")

    static let defaultQuery = HomeQuery()

    var id: String
    var displayString: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(id: String, displayString: String) {
        self.id = id
        self.displayString = displayString
    }

    @MainActor
    init(homePrefs: HomePreferences) {
        self.init(id: homePrefs.stableIdentifier, displayString: homePrefs.homeName)
    }
}

// MARK: - Stable Cross-Device Identifier

extension HomePreferences {
    /// A stable identifier that is the same on every device configured for the same openHAB server.
    /// Used as Home.id so that shortcuts synced via iCloud resolve correctly on a second device.
    ///
    /// Priority:
    /// 1. cloudUserId — unique per myopenhab.org account
    /// 2. remote URL — unique for self-hosted cloud servers
    /// 3. local URL — fallback for local-only setups
    /// 4. UUID string — last resort (no cross-device benefit, but avoids an empty identifier)
    var stableIdentifier: String {
        if let cloudId = remoteConnectionConfig.cloudUserId, !cloudId.isEmpty {
            return cloudId
        }
        if !remoteConnectionConfig.url.isEmpty {
            return remoteConnectionConfig.url
        }
        if !localConnectionConfig.url.isEmpty {
            return localConnectionConfig.url
        }
        return id.uuidString
    }
}
