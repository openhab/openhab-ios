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
struct SetSwitchState: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    enum Action: String, AppEnum {
        case on = "ON"
        case off = "OFF"

        static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
        static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
            .on: "ON",
            .off: "OFF"
        ]
    }

    static let intentClassName = "OpenHABSetSwitchStateIntent"

    static var title: LocalizedStringResource = "Set Switch State"
    static var description = IntentDescription("Set the state of a switch on or off")

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$item)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$action)) { item, action in
            DisplayRepresentation(
                title: "Send \(action) to \(item)",
                subtitle: ""
            )
        }
    }

    @Parameter(title: "Item")
    var item: ItemAppEntity

    @Parameter(title: "Action")
    var action: Action

    func perform() async throws -> some IntentResult {
        let validatedItem = await OpenHABItemCache.instance.getItem(name: item.id)
        OpenHABItemCache.instance.sendCommand(validatedItem!, commandToSend: action.rawValue)
        return .result()
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 16.0, *)
private extension IntentDialog {
    static var itemParameterConfiguration: Self {
        "Switch name"
    }

    static var actionParameterConfiguration: Self {
        "Action"
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
