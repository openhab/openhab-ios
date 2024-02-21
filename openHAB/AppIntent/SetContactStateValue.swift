//
//  SetContactStateValue.swift
//  
//
//  Created by Tim Müller-Seydlitz on 13.02.24.
//

import Foundation
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SetContactStateValue: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "OpenHABSetContactStateValueIntent"

    static var title: LocalizedStringResource = "Set Contact State Value"
    static var description = IntentDescription("Set the state of a contact open or closed")

    @Parameter(title: "Item", optionsProvider: StringOptionsProvider())
    var item: String?

    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            return []
        }
    }

    @Parameter(title: "State", optionsProvider: StringOptionsProvider())
    var state: String?

    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            return []
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set the state of \(\.$item) to \(\.$state)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$state)) { item, state in
            DisplayRepresentation(
                title: "Set the state of \(item!) to \(state!)",
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

