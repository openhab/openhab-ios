//
//  SetSwitchState.swift
//  
//
//  Created by Tim Müller-Seydlitz on 13.02.24.
//

import Foundation
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SetSwitchState: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "OpenHABSetSwitchStateIntent"

    static var title: LocalizedStringResource = "Set Switch State"
    static var description = IntentDescription("Set the state of a switch on or off")

    @Parameter(title: "Item", optionsProvider: StringOptionsProvider())
    var item: String?

    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            return []
        }
    }

    @Parameter(title: "Action", optionsProvider: StringOptionsProvider())
    var action: String?

    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            return []
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$item)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$action)) { item, action in
            DisplayRepresentation(
                title: "Send \(action!) to \(item!)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult {
        // TODO: Place your refactored intent handler code here.
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
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

