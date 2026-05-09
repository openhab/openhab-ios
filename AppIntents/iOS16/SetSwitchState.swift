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

@available(iOS, introduced: 16.0, obsoleted: 17.0)
enum SetSwitchStateError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotFound(String)
    case invalidAction(String, String)
    case itemNotInHome(String, String)
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        case let .invalidAction(action, itemName):
            "Action invalid: \(action) for \(itemName)"
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

// @available(iOS, introduced: 16.0, obsoleted: 17.0, message: "Use SwitchStateIntent for iOS 17+")
struct SetSwitchState: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    // swiftlint:disable type_contents_order

    static let intentClassName = "OpenHABSetSwitchStateIntent"
    static let title: LocalizedStringResource = "Set Switch State"
    static let description = IntentDescription("Set the state of a switch on or off")

    @Parameter(title: "Home")
    var home: Home?

    struct ItemOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let items = allItems.flatMap(\.value).filter { $0.type == .switchItem }
            return items.map(\.name)
        }
    }

    @Parameter(title: "Item", optionsProvider: ItemOptionsProvider())
    var item: String

    struct ActionOptionsProvider: DynamicOptionsProvider {
        func results() throws -> [String] {
            ActionMapper.onOffOptions
        }
    }

    @Parameter(title: "Action", optionsProvider: ActionOptionsProvider())
    var action: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$item)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$action, \.$home)) { item, action, _ in
            DisplayRepresentation(
                title: "Send \(action) to \(item)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let homeId = try await HomeResolver.resolveHomeId(
            selectedHome: home,
            itemName: item,
            allowedTypes: [.switchItem]
        )

        guard let command = ActionMapper.command(from: action) else {
            throw SetSwitchStateError.invalidAction(action, item)
        }
        guard let items = await OpenHABItemCache.instance.getCachedItem(name: item, home: homeId),
              !items.isEmpty else {
            throw SetSwitchStateError.itemNotFound(item)
        }

        let openHABItem = items[0]

        do {
            try await OpenHABItemCache.instance.sendCommand(to: openHABItem, home: homeId, command: command)
        } catch {
            throw SetSwitchStateError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: .responseSuccess(action: action, item: item))
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
