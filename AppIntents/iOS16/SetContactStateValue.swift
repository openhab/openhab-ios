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

enum SetContactStateValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotFound(String)
    case invalidState(String, String)
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        case let .invalidState(state, itemName):
            "State invalid: \(state) for \(itemName)"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

@available(iOS, introduced: 16.0, obsoleted: 17.0, message: "Use ContactStateIntent for iOS 17+")
struct SetContactStateValue: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    struct ItemOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            await Preferences.prepareForAppExtensionAccess()
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let items = allItems.flatMap(\.value).filter { $0.isOfTypeOrGroupType(.contact) }
            return items.map(\.name)
        }
    }

    struct StateOptionsProvider: DynamicOptionsProvider {
        func results() throws -> [String] {
            ActionMapper.onOffOptions
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
    var home: Home?

    static var parameterSummary: some ParameterSummary {
        Summary("Set the state of \(\.$item) to \(\.$state)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$state, \.$home)) { item, state, _ in
            DisplayRepresentation(
                title: "Set the state of \(item) to \(state)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let homeId = try await HomeResolver.resolveHomeId(
            selectedHome: home,
            itemName: item,
            allowedTypes: [.contact]
        )

        guard let realState = ActionMapper.command(from: state) else {
            throw SetContactStateValueError.invalidState(state, item)
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: item, home: homeId),
              !items.isEmpty else {
            throw SetContactStateValueError.itemNotFound(item)
        }

        let openHABItem = items[0]

        do {
            try await OpenHABItemCache.instance.sendCommand(to: openHABItem, home: homeId, command: realState)
        } catch {
            throw SetContactStateValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: .responseSuccess(item: item, state: state))
    }
}

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
