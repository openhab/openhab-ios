//
//  GetItemState.swift
//  
//
//  Created by Tim Müller-Seydlitz on 13.02.24.
//

import Foundation
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct GetItemState: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "OpenHABGetItemStateIntent"

    static var title: LocalizedStringResource = "Get Item State"
    static var description = IntentDescription("Retrieve the current state of an item")

    @Parameter(title: "Item", optionsProvider: StringOptionsProvider())
    var item: String?

    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            return []
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$item) State")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item)) { item in
            DisplayRepresentation(
                title: "Get \(item!) State",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // TODO: Place your refactored intent handler code here.
        return .result(value: String(/* fill in result initializer here */))
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
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

