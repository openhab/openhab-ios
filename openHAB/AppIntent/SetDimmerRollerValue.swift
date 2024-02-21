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
struct SetDimmerRollerValue: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "OpenHABSetDimmerRollerValueIntent"

    static var title: LocalizedStringResource = "Set Dimmer or Roller Shutter Value"
    static var description = IntentDescription("Set the integer value of a dimmer or roller shutter")

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$item) to \(\.$value)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$value)) { item, value in
            DisplayRepresentation(
                title: "Set \(item) to \(value)",
                subtitle: ""
            )
        }
    }

    @Parameter(title: "Item")
    var item: ItemAppEntity

    @Parameter(title: "Value")
    var value: Int

    func perform() async throws -> some IntentResult {
        let validatedItem = await OpenHABItemCache.instance.getItem(name: item.id)
        OpenHABItemCache.instance.sendCommand(validatedItem!, commandToSend: String(value))
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var itemParameterConfiguration: Self {
        "Dimmer/Roller Name"
    }

    static func responseSuccess(value: Int, item: String) -> Self {
        "Sent the value of \(value) to \(item)"
    }

    static func responseFailureInvalidItem(item: String) -> Self {
        "Sorry can't find \(item)"
    }

    static func responseFailureEmptyValue(item: String) -> Self {
        "Invalid empty value for \(item)"
    }

    static func responseFailureInvalidValue(value: Int, item: String) -> Self {
        "Invalid value \(value) for \(item) (0-100)"
    }
}
