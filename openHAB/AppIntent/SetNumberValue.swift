//
//  SetNumberValue.swift
//  
//
//  Created by Tim Müller-Seydlitz on 13.02.24.
//

import Foundation
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SetNumberValue: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "OpenHABSetNumberValueIntent"

    static var title: LocalizedStringResource = "Set Number Control Value"
    static var description = IntentDescription("Set the decimal value of a number control item")

    @Parameter(title: "Item", optionsProvider: StringOptionsProvider())
    var item: String?

    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            return []
        }
    }

    @Parameter(title: "Value")
    var value: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$item) to \(\.$value)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$value)) { item, value in
            DisplayRepresentation(
                title: "Set \(item!) to \(value!)",
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
        "Dimmer/Roller Name"
    }
    static func responseSuccess(value: Double, item: String) -> Self {
        "Sent the number \(value) to \(item)"
    }
    static func responseFailureInvalidItem(item: String) -> Self {
        "Sorry can't find \(item)"
    }
    static func responseFailureEmptyValue(item: String) -> Self {
        "Invalid empty value for \(item)"
    }
}

