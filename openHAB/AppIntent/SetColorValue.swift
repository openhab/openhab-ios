//
//  SetColorValue.swift
//  
//
//  Created by Tim Müller-Seydlitz on 13.02.24.
//

import Foundation
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SetColorValue: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "OpenHABSetColorValueIntent"

    static var title: LocalizedStringResource = "Set Color Control Value"
    static var description = IntentDescription("Set the color of a color control item")

    @Parameter(title: "Item", optionsProvider: StringOptionsProvider())
    var item: String?

    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            return []
        }
    }

    @Parameter(title: "Value", default: "240,100,100")
    var value: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$item) to \(\.$value) (HSB)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$value)) { item, value in
            DisplayRepresentation(
                title: "Set \(item!) to \(value!) (HSB)",
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

