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

enum SetSwitchStateError: Error, CustomLocalizedStringResourceConvertible {
    case invalidAction(String, String)
    case itemNotInHome(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .invalidAction(action, itemName):
            "Action invalid: \(action) for \(itemName)"
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        }
    }
}

struct SetSwitchState: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    struct ActionOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            [
                String(localized: "on").capitalized,
                String(localized: "off").capitalized
            ]
        }
    }

    static let intentClassName = "OpenHABSetSwitchStateIntent"

    static let title: LocalizedStringResource = "Set Switch State"
    static let description = IntentDescription("Set the state of a switch on or off")

    // swiftlint:disable type_contents_order
    @Parameter(title: "Home")
    var home: Home

    @Parameter(title: "Item")
    var item: ItemAppEntity

    @Parameter(title: "Action", optionsProvider: ActionOptionsProvider())
    var action: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$item)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$home, \.$item, \.$action)) { home, item, action in
            DisplayRepresentation(
                title: "Send \(action) to \(item.label)",
                subtitle: "in \(home.displayString)"
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Validate that the item belongs to the selected home
        guard let homeId = UUID(uuidString: home.id), homeId == item.homeId else {
            throw SetSwitchStateError.itemNotInHome(item.label, home.displayString)
        }

        let onLabel = String(localized: "on").capitalized
        let offLabel = String(localized: "off").capitalized
        let actionMap: [String: String] = [
            onLabel: "ON",
            offLabel: "OFF"
        ]

        guard let command = actionMap[action] else {
            throw SetSwitchStateError.invalidAction(action, item.label)
        }

        await OpenHABItemCache.instance.sendCommand(to: item.item, home: item.homeId, command: command)

        return .result(dialog: .responseSuccess(action: action, item: item.label))
    }
}

private extension IntentDialog {
    static func responseSuccess(action: String, item: String) -> Self {
        "Sent the action of \(action) to switch \(item)"
    }

    static func responseFailureInvalidAction(action: String, item: String) -> Self {
        "Action invalid: \(action) for \(item)"
    }
}
