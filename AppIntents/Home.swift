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
                               itemHomeId: UUID?,
                               itemLabel: String,
                               stableIdentifierToLocalUUID: [(String, UUID)] = [],
                               mismatchError: (String, String) -> some Error) throws -> UUID {
        guard let selectedHome else {
            guard let itemHomeId else {
                throw HomeResolutionError.unknownHome
            }
            return itemHomeId
        }

        let homeId: UUID
        if let match = stableIdentifierToLocalUUID.first(where: { $0.0 == selectedHome.id }) {
            homeId = match.1
        } else if let match = stableIdentifierToLocalUUID.first(where: { $0.0 == Home.stableIdentifierComponent(of: selectedHome.id) }) {
            homeId = match.1
        } else if let uuid = UUID(uuidString: selectedHome.id) {
            homeId = uuid
        } else if let uuid = UUID(uuidString: Home.stableIdentifierComponent(of: selectedHome.id)) {
            homeId = uuid
        } else {
            throw HomeResolutionError.unknownHome
        }

        guard let itemHomeId else {
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
                               itemHomeId: UUID?,
                               itemLabel: String,
                               mismatchError: (String, String) -> some Error) throws -> UUID {
        // Map entries use the storedHomes dict key (not HomePreferences.id) so the resolved UUID
        // matches the dict key stored in ItemIdentifier.homeId by entities(for:) — both sides of
        // the guard homeId == itemHomeId check are then the same value.
        let storedHomes = Preferences.shared.storedHomes
        // Count occurrences of each stableIdentifier so bare-name entries are only added when
        // unique — mirrors resolvePreferences(for:in:) which requires a unique stable-id match.
        let stableIdCounts = storedHomes.values.reduce(into: [String: Int]()) { $0[$1.stableIdentifier, default: 0] += 1 }
        let map = storedHomes.flatMap { key, prefs -> [(String, UUID)] in
            var entries: [(String, UUID)] = [("\(prefs.stableIdentifier)##\(prefs.id.uuidString)", key)]
            if stableIdCounts[prefs.stableIdentifier] == 1 {
                entries.append((prefs.stableIdentifier, key))
            }
            return entries
        }
        return try resolvedHomeId(
            selectedHome: selectedHome,
            itemHomeId: itemHomeId,
            itemLabel: itemLabel,
            stableIdentifierToLocalUUID: map,
            mismatchError: mismatchError
        )
    }

    /// Production overload for item-by-name resolution.
    /// Builds a stable-identifier-aware `findHomeId` closure and delegates to the testable overload.
    static func resolveHomeId(selectedHome: Home?,
                              itemName: String,
                              allowedTypes: [OpenHABItem.ItemType]? = nil) async throws -> UUID {
        await Preferences.prepareForAppExtensionAccess()

        return try await resolveHomeId(
            selectedHome: selectedHome,
            itemName: itemName,
            findHomeId: { identifier in
                await MainActor.run {
                    Home.resolveStoredHomeKey(for: identifier, in: Preferences.shared.storedHomes)
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
            let stableId = Home.stableIdentifierComponent(of: selectedHome.id)
            let homeId = if let exactHomeId = await findHomeId(selectedHome.id) {
                exactHomeId
            } else {
                await findHomeId(stableId)
            }
            guard let homeId else {
                throw HomeResolutionError.unknownHome
            }
            return homeId
        }

        let storedHomes = await listStoredHomes()
        guard !storedHomes.isEmpty else {
            throw HomeResolutionError.unknownHome
        }
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
                guard let prefs = Home.resolvePreferences(for: identifier, in: storedHomes) else { return nil }
                // Return the home with the ORIGINAL identifier so Home.id matches what the
                // framework stored — prevents cross-device mismatch when the ##UUID suffix
                // differs between the creating device and the running device.
                return Home(id: identifier, displayString: prefs.homeName)
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
        // Append the local UUID after "##" to disambiguate homes that share the same
        // stableIdentifier (e.g. same local URL on two different networks). Resolution
        // tries an exact match first, then falls back to stableIdentifier-only so
        // shortcuts synced from another device still resolve.
        self.init(id: "\(homePrefs.stableIdentifier)##\(homePrefs.id.uuidString)", displayString: homePrefs.homeName)
    }

    /// Extracts the stable-identifier portion from a Home.id.
    ///
    /// Current format: `"<stableIdentifier>##<localUUID>"` — returns the prefix.
    /// Legacy formats (`"<stableIdentifier>"` or a raw UUID string) — returned as-is.
    static func stableIdentifierComponent(of homeId: ID) -> String {
        homeId.components(separatedBy: "##").first ?? homeId
    }

    /// Extracts the device-local UUID suffix from a current-format Home.id.
    static func localIdentifierComponent(of homeId: ID) -> UUID? {
        let components = homeId.components(separatedBy: "##")
        guard components.count == 2 else { return nil }
        return UUID(uuidString: components[1])
    }

    /// Resolves a home identifier string to the `storedHomes` dictionary key for the matching entry.
    ///
    /// Unlike `resolvePreferences(for:in:)?.id`, this always returns the canonical dictionary key.
    /// The key may differ from `HomePreferences.id` when stored data has a key/id mismatch.
    @MainActor
    static func resolveStoredHomeKey(for identifier: String, in storedHomes: [UUID: HomePreferences]) -> UUID? {
        guard let prefs = resolvePreferences(for: identifier, in: storedHomes) else { return nil }
        return storedHomes.first { $0.value.id == prefs.id }?.key ?? prefs.id
    }

    @MainActor
    static func resolvePreferences(for identifier: String, in storedHomes: [UUID: HomePreferences]) -> HomePreferences? {
        if identifier.contains("##") {
            // Current format: "stableIdentifier##localUUID"
            // Exact match: same device, stableIdentifier unchanged since shortcut was created.
            if let match = storedHomes.values.first(where: { identifier == "\($0.stableIdentifier)##\($0.id.uuidString)" }) {
                return match
            }
            // Local UUID match: same device, stableIdentifier changed (home renamed, URL updated, or
            // cloudUserId populated after shortcut creation). Falls back to id-field scan for stored
            // data where the dictionary key and HomePreferences.id differ.
            if let localId = localIdentifierComponent(of: identifier) {
                if let match = storedHomes[localId] { return match }
                if let match = storedHomes.values.first(where: { $0.id == localId }) { return match }
            }
            // Stable identifier match: cross-device resolution.
            // Require a unique match — if two homes share a name the fallback is ambiguous and
            // a re-pick is safer than silently running against the wrong server.
            let stableId = stableIdentifierComponent(of: identifier)
            let stableMatches = storedHomes.values.filter { $0.stableIdentifier == stableId }
            if stableMatches.count == 1 { return stableMatches.first }
        } else {
            // Legacy format (pre-## era): raw UUID string or bare stable identifier.
            if let uuid = UUID(uuidString: identifier) {
                if let match = storedHomes[uuid] ?? storedHomes.values.first(where: { $0.id == uuid }) {
                    return match
                }
            }
            let stableMatches = storedHomes.values.filter { $0.stableIdentifier == identifier }
            if stableMatches.count == 1 { return stableMatches.first }
        }
        return nil
    }
}

// MARK: - Stable Cross-Device Identifier

extension HomePreferences {
    /// A stable identifier that is the same on every device configured for the same openHAB server.
    /// Used as Home.id so that shortcuts synced via iCloud resolve correctly on a second device.
    ///
    /// Uses only homeName so that the identifier is independent of device-specific connection
    /// config (protocol, port, URL) — these often differ between devices (e.g. http/8080 on one
    /// device, https/8443 on another), which would break cross-device shortcut resolution.
    /// Home names are expected to be unique per user; the UUID fallback handles the unnamed case.
    var stableIdentifier: String {
        homeName.isEmpty ? id.uuidString : homeName
    }
}
