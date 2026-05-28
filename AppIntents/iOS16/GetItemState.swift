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

enum GetItemStateError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        }
    }
}

@available(iOS, introduced: 16.0, obsoleted: 17.0, message: "Use GetItemStateIntent for iOS 17+")
struct GetItemState: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            await Preferences.prepareForAppExtensionAccess()
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            return allItems.flatMap { $0.value.map(\.name) }
        }
    }

    static let intentClassName = "OpenHABGetItemStateIntent"

    static let title: LocalizedStringResource = "Get Item State"
    static let description = IntentDescription("Retrieve the current state of an item")

    // swiftlint:disable type_contents_order
    @Parameter(title: "Item", optionsProvider: StringOptionsProvider())
    var item: String

    @Parameter(title: "Home")
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
                title: "Get \(item) State",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let homeId = try await HomeResolver.resolveHomeId(
            selectedHome: home,
            itemName: item
        )

        guard let openHABItem = await OpenHABItemCache.instance.getItemUncached(name: item, home: homeId) else {
            throw GetItemStateError.itemNotFound(item)
        }

        let state = openHABItem.state ?? "Unknown state"

        return .result(
            value: state,
            dialog: .responseSuccess(item: item, state: state)
        )
    }
}

private extension IntentDialog {
    static func responseSuccess(item: String, state: String) -> Self {
        "The state of \(item) is \(state)"
    }
}
