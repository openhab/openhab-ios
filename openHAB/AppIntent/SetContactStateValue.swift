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
struct SetContactStateValue: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            []
        }
    }

    enum Contact: String, AppEnum {
        case open = "OPEN"
        case close = "CLOSE"

        static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
        static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
            .open: "OPEN",
            .close: "CLOSE"
        ]
    }

    static let intentClassName = "OpenHABSetContactStateValueIntent"

    static var title: LocalizedStringResource = "Set Contact State Value"
    static var description = IntentDescription("Set the state of a contact open or closed")

    static var parameterSummary: some ParameterSummary {
        Summary("Set the state of \(\.$item) to \(\.$state)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$state)) { item, state in
            DisplayRepresentation(
                title: "Set the state of \(item) to \(state)",
                subtitle: ""
            )
        }
    }

    @Parameter(title: "Item")
    var item: ItemAppEntity

    @Parameter(title: "State")
    var state: Contact

    func perform() async throws -> some IntentResult {
        let validatedItem = await OpenHABItemCache.instance.getItem(name: item.id)
        OpenHABItemCache.instance.sendCommand(validatedItem!, commandToSend: state.rawValue)
        return .result()
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
