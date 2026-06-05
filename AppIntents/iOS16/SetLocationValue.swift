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

enum SetLocationValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotFound(String)
    case invalidLatitude
    case invalidLongitude
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        case .invalidLatitude:
            "Latitude must be between -90 and 90"
        case .invalidLongitude:
            "Longitude must be between -180 and 180"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

@available(iOS, introduced: 16.0, obsoleted: 17.0, message: "Use SetLocationValueIntent for iOS 17+")
struct SetLocationValue: AppIntent, PredictableIntent {
    struct LocationOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            await Preferences.prepareForAppExtensionAccess()
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let items = allItems.flatMap(\.value).filter { $0.isOfTypeOrGroupType(.location) }
            return items.map(\.name)
        }
    }

    static let title: LocalizedStringResource = "Set Location Control Value"
    static let description = IntentDescription("Set the latitude and longitude of a location control item")

    // swiftlint:disable type_contents_order
    @Parameter(title: "Item", optionsProvider: LocationOptionsProvider())
    var item: String

    @Parameter(title: "Latitude")
    var latitude: Double

    @Parameter(title: "Longitude")
    var longitude: Double

    @Parameter(title: "Home")
    var home: Home?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$item) to \(\.$latitude), \(\.$longitude)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$latitude, \.$longitude, \.$home)) { item, latitude, longitude, _ in
            DisplayRepresentation(
                title: "Set \(item) to \(latitude), \(longitude)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let homeId = try await HomeResolver.resolveHomeId(
            selectedHome: home,
            itemName: item,
            allowedTypes: [.location]
        )

        guard (-90 ... 90).contains(latitude) else {
            throw SetLocationValueError.invalidLatitude
        }

        guard (-180 ... 180).contains(longitude) else {
            throw SetLocationValueError.invalidLongitude
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: item, home: homeId),
              !items.isEmpty else {
            throw SetLocationValueError.itemNotFound(item)
        }

        let openHABItem = items[0]
        let command = "\(latitude),\(longitude)"

        do {
            try await OpenHABItemCache.instance.sendCommand(to: openHABItem, home: homeId, command: command)
        } catch {
            throw SetLocationValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: "Sent location \(latitude), \(longitude) to \(item)")
    }
}
