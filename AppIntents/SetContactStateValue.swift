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

enum SetContactStateValueError: Error, CustomLocalizedStringResourceConvertible {
    case invalidHomeIdentifier
    case unknownHome
    case itemNotFound(String)
    case invalidState(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidHomeIdentifier:
            "Invalid home identifier"
        case .unknownHome:
            "Unknown home"
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        case let .invalidState(state, itemName):
            "State invalid: \(state) for \(itemName)"
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SetContactStateValue: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    struct ItemOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let items = allItems.flatMap(\.value).filter { $0.type == .contact }
            return items.map(\.name)
        }
    }

    struct StateOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            [
                NSLocalizedString("on", comment: "").capitalized,
                NSLocalizedString("off", comment: "").capitalized
            ]
        }
    }

    static let intentClassName = "OpenHABSetContactStateValueIntent"

    static let title: LocalizedStringResource = "Set Contact State Value"
    static let description = IntentDescription("Set the state of a contact open or closed")

    // swiftlint:disable type_contents_order
    @Parameter(title: "Item", optionsProvider: ItemOptionsProvider())
    var item: String

    @Parameter(title: "State", optionsProvider: StateOptionsProvider())
    var state: String

    @Parameter(title: "Home")
    var home: Home

    static var parameterSummary: some ParameterSummary {
        Summary("Set the state of \(\.$item) to \(\.$state)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$state, \.$home)) { item, state, _ in
            DisplayRepresentation(
                title: "Set the state of \(item!) to \(state!)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let homeId = UUID(uuidString: home.id) else {
            throw SetContactStateValueError.invalidHomeIdentifier
        }

        let homeExists = await MainActor.run {
            Preferences.shared.storedHomes[homeId] != nil
        }

        guard homeExists else {
            throw SetContactStateValueError.unknownHome
        }

        let onLabel = NSLocalizedString("on", comment: "").capitalized
        let offLabel = NSLocalizedString("off", comment: "").capitalized
        let actionMap: [String: String] = [
            onLabel: "ON",
            offLabel: "OFF"
        ]

        guard let realState = actionMap[state] else {
            throw SetContactStateValueError.invalidState(state, item)
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: item, home: homeId),
              !items.isEmpty else {
            throw SetContactStateValueError.itemNotFound(item)
        }

        let openHABItem = items[0]

        await OpenHABItemCache.instance.sendCommand(to: openHABItem, home: homeId, command: realState)

        return .result(dialog: .responseSuccess(item: item, state: state))
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var itemParameterConfiguration: Self {
        "Switch name"
    }

    static var stateParameterConfiguration: Self {
        "Action"
    }

    static var homeParameterConfiguration: Self {
        "Home name"
    }

    static var homeParameterDisambiguationSelection: Self {
        "For which home do you want to get the value?"
    }

    static func homeParameterDisambiguationIntro(count: Int, item: String) -> Self {
        "There are \(count) configured homes with an item named '\(item)'."
    }

    static func homeParameterConfirmation(home: Home) -> Self {
        "Just to confirm, you wanted '\(home)'?"
    }

    static func responseSuccess(item: String, state: String) -> Self {
        "The state of \(item) was set to \(state)"
    }

    static func responseFailureInvalidItem(item: String) -> Self {
        "Sorry can't find \(item)"
    }

    static func responseFailureInvalidAction(state: String, item: String) -> Self {
        "State invalid: \(state) for \(item)"
    }
}
