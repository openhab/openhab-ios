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
    case invalidHomeIdentifier
    case unknownHome
    case itemNotFound(String)
    case invalidAction(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidHomeIdentifier:
            "Invalid home identifier"
        case .unknownHome:
            "Unknown home"
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        case let .invalidAction(action, itemName):
            "Action invalid: \(action) for \(itemName)"
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SetSwitchState: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    struct ItemOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let items = allItems.flatMap(\.value).filter { $0.type == .switchItem }
            return items.map(\.name)
        }
    }

    struct ActionOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            [
                NSLocalizedString("on", comment: "").capitalized,
                NSLocalizedString("off", comment: "").capitalized
            ]
        }
    }

    static let intentClassName = "OpenHABSetSwitchStateIntent"

    static let title: LocalizedStringResource = "Set Switch State"
    static let description = IntentDescription("Set the state of a switch on or off")

    // swiftlint:disable type_contents_order
    @Parameter(title: "Item", optionsProvider: ItemOptionsProvider())
    var item: String?

    @Parameter(title: "Action", optionsProvider: ActionOptionsProvider())
    var action: String?

    @Parameter(title: "home")
    var home: Home?

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$item)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$action, \.$home)) { item, action, _ in
            DisplayRepresentation(
                title: "Send \(action!) to \(item!)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let itemName = item, !itemName.isEmpty else {
            throw $item.needsValueError()
        }

        guard let action else {
            throw $action.needsValueError()
        }

        guard let home else {
            throw $home.needsValueError()
        }

        guard let homeId = UUID(uuidString: home.id) else {
            throw SetSwitchStateError.invalidHomeIdentifier
        }

        let homeExists = await MainActor.run {
            Preferences.shared.storedHomes[homeId] != nil
        }

        guard homeExists else {
            throw SetSwitchStateError.unknownHome
        }

        let onLabel = NSLocalizedString("on", comment: "").capitalized
        let offLabel = NSLocalizedString("off", comment: "").capitalized
        let actionMap: [String: String] = [
            onLabel: "ON",
            offLabel: "OFF"
        ]

        guard let command = actionMap[action] else {
            throw SetSwitchStateError.invalidAction(action, itemName)
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: itemName, home: homeId),
              !items.isEmpty else {
            throw SetSwitchStateError.itemNotFound(itemName)
        }

        let item = items[0]

        await OpenHABItemCache.instance.sendCommand(to: item, home: homeId, command: command)

        return .result(dialog: .responseSuccess(action: action, item: itemName))
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var itemParameterConfiguration: Self {
        "Switch name"
    }

    static var actionParameterConfiguration: Self {
        "Action"
    }

    static var homeParameterConfiguration: Self {
        "Home name"
    }

    static var homeParameterDisambiguationSelection: Self {
        "For which home do you want to get the value?"
    }

    static func homeParameterDisambiguationIntro(count: Int, item: String) -> Self {
        "There are \(count) configured homes with an item named '\(item)''."
    }

    static func homeParameterConfirmation(home: Home) -> Self {
        "Just to confirm, you wanted '\(home)'?"
    }

    static func responseSuccess(action: String, item: String) -> Self {
        "Sent the action of \(action) to switch \(item)"
    }

    static func responseFailureInvalidItem(item: String) -> Self {
        "Sorry can't find \(item)"
    }

    static func responseFailureInvalidAction(action: String, item: String) -> Self {
        "Action invalid: \(action) for \(item)"
    }
}
