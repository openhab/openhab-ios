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
struct SetColorValue: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "OpenHABSetColorValueIntent"

    static var title: LocalizedStringResource = "Set Color Control Value"
    static var description = IntentDescription("Set the color of a color control item")

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$item) to \(\.$value) (HSB)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$value)) { item, value in
            DisplayRepresentation(
                title: "Set \(item) to \(value) (HSB)",
                subtitle: ""
            )
        }
    }

    @Parameter(title: "Item")
    var item: ItemAppEntity

    @Parameter(title: "Value", default: "240,100,100")
    var value: String

    func perform() async throws -> some IntentResult {
        let validatedItem = await OpenHABItemCache.instance.getItem(name: item.id)
        OpenHABItemCache.instance.sendCommand(validatedItem!, commandToSend: value)
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var itemParameterConfiguration: Self {
        "Dimmer/Roller Name"
    }

    static func responseSuccess(value: String, item: String) -> Self {
        "Sent the color value of \(value) to \(item)"
    }

    static func responseFailureInvalidItem(item: String) -> Self {
        "Sorry can't find \(item)"
    }

    static func responseFailureInvalidValue(value: String, item: String) -> Self {
        "Invalid value: \(value) for \(item) must be HSB (0-360,0-100,0-100)"
    }
}
