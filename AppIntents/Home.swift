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

struct Home: AppEntity {
    struct HomeQuery: EntityQuery {
        @MainActor
        func entities(for identifiers: [Home.ID]) async throws -> [Home] {
            identifiers.compactMap { identifier in
                guard let uuid = UUID(uuidString: identifier),
                      let homePrefs = Preferences.shared.storedHomes[uuid] else {
                    return nil
                }
                return Home(id: homePrefs.id.uuidString, displayString: homePrefs.homeName)
            }
        }

        @MainActor
        func suggestedEntities() async throws -> [Home] {
            Preferences.shared.storedHomes.values
                .sorted {
                    let nameOrder = $0.homeName.localizedCaseInsensitiveCompare($1.homeName)
                    if nameOrder != .orderedSame {
                        return nameOrder == .orderedAscending
                    }
                    return $0.id.uuidString < $1.id.uuidString
                }
                .map { homePrefs in
                    Home(id: homePrefs.id.uuidString, displayString: homePrefs.homeName)
                }
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
}

enum HomeResolutionError: Error, CustomLocalizedStringResourceConvertible {
    case invalidHomeIdentifier
    case unknownHome
    case ambiguousHomeSelection(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidHomeIdentifier:
            "Invalid home identifier"
        case .unknownHome:
            "Unknown home"
        case let .ambiguousHomeSelection(itemName):
            "Select a home for '\(itemName)'"
        }
    }
}

enum HomeResolver {
    static func resolvedHomeId<E: Error>(
        selectedHome: Home?,
        itemHomeId: UUID,
        itemLabel: String,
        mismatchError: (String, String) -> E
    ) throws -> UUID {
        guard let selectedHome else {
            return itemHomeId
        }

        guard let homeId = UUID(uuidString: selectedHome.id) else {
            throw HomeResolutionError.invalidHomeIdentifier
        }

        guard homeId == itemHomeId else {
            throw mismatchError(itemLabel, selectedHome.displayString)
        }

        return homeId
    }

    static func resolveHomeId(
        selectedHome: Home?,
        itemName: String,
        allowedTypes: [OpenHABItem.ItemType]? = nil
    ) async throws -> UUID {
        try await resolveHomeId(
            selectedHome: selectedHome,
            itemName: itemName,
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

    static func resolveHomeId(
        selectedHome: Home?,
        itemName: String,
        listStoredHomes: @escaping () async -> [UUID],
        exactMatchedHomes: @escaping () async -> Set<UUID>
    ) async throws -> UUID {
        if let selectedHome {
            guard let homeId = UUID(uuidString: selectedHome.id) else {
                throw HomeResolutionError.invalidHomeIdentifier
            }

            let storedHomes = await listStoredHomes()
            guard storedHomes.contains(homeId) else {
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
