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

import AppIntents
import Foundation
import OpenHABCore

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
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
            Preferences.shared.storedHomes.map { homePrefs in
                Home(id: homePrefs.value.id.uuidString, displayString: homePrefs.value.homeName)
            }
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Home")

    static let defaultQuery = HomeQuery()

    var id: String // if your identifier is not a String, conform the entity to EntityIdentifierConvertible.
    var displayString: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(id: String, displayString: String) {
        self.id = id
        self.displayString = displayString
    }
}
