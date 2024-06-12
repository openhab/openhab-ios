// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import Intents
import OpenHABCore
import os.log

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct GetItemState: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "OpenHABGetItemStateIntent"

    static var title: LocalizedStringResource = "Get Item State"
    static var description = IntentDescription("Retrieve the current state of an item")

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$item) State")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item)) { item in
            DisplayRepresentation(
                title: "Get \(item) State",
                subtitle: ""
            )
        }
    }

    @Parameter(title: "Item")
    var item: ItemAppEntity

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let validatedItem = await OpenHABItemCache.instance.getItem(name: item.id)
        return .result(value: validatedItem?.state ?? NSLocalizedString("unknown", comment: "unknown item"))
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var itemParameterConfiguration: Self {
        "Item Name"
    }

    static func responseSuccess(item: String, state: String) -> Self {
        "The state of \(item) is \(state)"
    }

    static func responseFailureInvalidItem(item: String) -> Self {
        "Sorry can't find \(item)"
    }
}
