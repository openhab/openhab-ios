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

enum GetItemStateError: Error, CustomLocalizedStringResourceConvertible {
    case invalidHomeIdentifier
    case unknownHome
    case itemNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidHomeIdentifier:
            "Invalid home identifier"
        case .unknownHome:
            "Unknown home"
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GetItemState: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            return allItems.flatMap { $0.value.map(\.name) }
        }
    }

    static let intentClassName = "OpenHABGetItemStateIntent"

    static let title: LocalizedStringResource = "Get Item State"
    static let description = IntentDescription("Retrieve the current state of an item")

    // swiftlint:disable type_contents_order
    @Parameter(title: "Item", optionsProvider: StringOptionsProvider())
    var item: String?

    @Parameter(title: "home")
    var home: Home?

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$item) State") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$home)) { item, _ in
            DisplayRepresentation(
                title: "Get \(item!) State",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let itemName = item, !itemName.isEmpty else {
            throw $item.needsValueError()
        }

        guard let home else {
            throw $home.needsValueError()
        }

        guard let homeId = UUID(uuidString: home.id) else {
            throw GetItemStateError.invalidHomeIdentifier
        }

        let homeExists = await MainActor.run {
            Preferences.shared.storedHomes[homeId] != nil
        }

        guard homeExists else {
            throw GetItemStateError.unknownHome
        }

        guard let item = await OpenHABItemCache.instance.getItemUncached(name: itemName, home: homeId) else {
            throw GetItemStateError.itemNotFound(itemName)
        }

        let state = item.state ?? "Unknown state"

        return .result(
            value: state,
            dialog: .responseSuccess(item: itemName, state: state)
        )
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var itemParameterConfiguration: Self {
        "Item Name"
    }

    static var homeParameterConfiguration: Self {
        "Home name"
    }

    static var homeParameterPrompt: Self {
        "blabla"
    }

    static var homeParameterDisambiguationSelection: Self {
        "For which home do you want to get the value?"
    }

    static func homeParameterDisambiguationIntro(count: Int, item: String) -> Self {
        "There are \(count) configured homes with an item named '\(item)'’."
    }

    static func homeParameterConfirmation(home: Home) -> Self {
        "Just to confirm, you wanted ‘\(home)’?"
    }

    static func responseSuccess(item: String, state: String) -> Self {
        "The state of \(item) is \(state)"
    }

    static func responseFailureInvalidItem(item: String) -> Self {
        "Sorry can't find \(item)"
    }
}
