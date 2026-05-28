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

enum LocationValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)
    case invalidLatitude
    case invalidLongitude
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        case .invalidLatitude:
            "Latitude must be between -90 and 90"
        case .invalidLongitude:
            "Longitude must be between -180 and 180"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct SetLocationValueIntent: AppIntent {
    static var openAppWhenRun: Bool {
        false
    }

    static var allowedItemTypes: [OpenHABItem.ItemType] {
        [.location]
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$itemEntity) to \(\.$latitude), \(\.$longitude)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set Location Control Value"
    static let description = IntentDescription("Set the latitude and longitude of a location control item")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("Search for an item")
    )
    var itemEntity: LocationItemEntity

    @Parameter(title: "Latitude")
    var latitude: Double

    @Parameter(title: "Longitude")
    var longitude: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Preferences.prepareForAppExtensionAccess()

        let homeId = try await HomeResolver.resolvedHomeId(
            selectedHome: home,
            itemHomeId: itemEntity.homeId,
            itemLabel: itemEntity.label,
            mismatchError: LocationValueError.itemNotInHome
        )

        guard (-90 ... 90).contains(latitude) else {
            throw LocationValueError.invalidLatitude
        }

        guard (-180 ... 180).contains(longitude) else {
            throw LocationValueError.invalidLongitude
        }

        let command = "\(latitude),\(longitude)"

        do {
            try await OpenHABItemCache.instance.sendCommand(
                to: itemEntity.item,
                home: homeId,
                command: command
            )
        } catch {
            throw LocationValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: "Sent location \(latitude), \(longitude) to \(itemEntity.label)")
    }
}
