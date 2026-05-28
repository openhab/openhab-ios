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

enum SetDateTimeValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotFound(String)
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

@available(iOS, introduced: 16.0, obsoleted: 17.0, message: "Use SetDateTimeValueIntent for iOS 17+")
struct SetDateTimeValue: AppIntent, PredictableIntent {
    struct DateTimeOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            await Preferences.prepareForAppExtensionAccess()
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let items = allItems.flatMap(\.value).filter { $0.type == .dateTime }
            return items.map(\.name)
        }
    }

    static let title: LocalizedStringResource = "Set DateTime Control Value"
    static let description = IntentDescription("Set the date and time of a DateTime control item")

    // swiftlint:disable type_contents_order
    @Parameter(title: "Item", optionsProvider: DateTimeOptionsProvider())
    var item: String

    @Parameter(title: "Date and Time")
    var value: Date

    @Parameter(title: "Home")
    var home: Home?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$item) to \(\.$value)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$value, \.$home)) { item, value, _ in
            DisplayRepresentation(
                title: "Set \(item) to \(value)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let homeId = try await HomeResolver.resolveHomeId(
            selectedHome: home,
            itemName: item,
            allowedTypes: [.dateTime]
        )

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: item, home: homeId),
              !items.isEmpty else {
            throw SetDateTimeValueError.itemNotFound(item)
        }

        let openHABItem = items[0]

        let command = value.formatted(Date.ISO8601FormatStyle(timeZone: .gmt))

        do {
            try await OpenHABItemCache.instance.sendCommand(to: openHABItem, home: homeId, command: command)
        } catch {
            throw SetDateTimeValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: "Sent the date \(command) to \(item)")
    }
}
