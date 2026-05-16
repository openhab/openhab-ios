// Copyright (c) 2010-2026 Contributors to the openHAB project
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
import OpenHABCore

enum SetColorValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotFound(String)
    case invalidValue(String, String)
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        case let .invalidValue(value, itemName):
            "Invalid value: \(value) for \(itemName) must be HSB (0-360,0-100,0-100)"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

@available(iOS, introduced: 16.0, obsoleted: 17.0, message: "Use SetColorValueIntent for iOS 17+")
struct SetColorValue: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            await Preferences.prepareForAppExtensionAccess()
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let items = allItems.flatMap(\.value).filter { $0.type == .color }
            return items.map(\.name)
        }
    }

    static let intentClassName = "OpenHABSetColorValueIntent"

    static let title: LocalizedStringResource = "Set Color Control Value"
    static let description = IntentDescription("Set the color of a color control item")

    // swiftlint:disable type_contents_order
    @Parameter(title: "Item", optionsProvider: StringOptionsProvider())
    var item: String

    @Parameter(title: "Value", default: "240,100,100")
    var value: String

    @Parameter(title: "Home")
    var home: Home?

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$item) to \(\.$value) (HSB)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$value, \.$home)) { item, value, _ in
            DisplayRepresentation(
                title: "Set \(item) to \(value) (HSB)",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var colorValue = value

        let homeId = try await HomeResolver.resolveHomeId(
            selectedHome: home,
            itemName: item,
            allowedTypes: [.color]
        )

        let hsb = colorValue.split(separator: ",")
        guard hsb.count == 3,
              let hue = Int(hsb[0]), (0 ... 360).contains(hue),
              let sat = Int(hsb[1]), (0 ... 100).contains(sat),
              let val = Int(hsb[2]), (0 ... 100).contains(val) else {
            throw SetColorValueError.invalidValue(colorValue, item)
        }

        colorValue = "\(hue),\(sat),\(val)"

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: item, home: homeId),
              !items.isEmpty else {
            throw SetColorValueError.itemNotFound(item)
        }

        let openHABItem = items[0]

        do {
            try await OpenHABItemCache.instance.sendCommand(to: openHABItem, home: homeId, command: colorValue)
        } catch {
            throw SetColorValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: .responseSuccess(value: colorValue, item: item))
    }
}

private extension IntentDialog {
    static var itemParameterConfiguration: Self {
        "Color Item Name"
    }

    static var homeParameterConfiguration: Self {
        "Home name"
    }

    static var homeParameterDisambiguationSelection: Self {
        "For which home do you want to get the value?"
    }

    static func homeParameterDisambiguationIntro(count: Int, item: String) -> Self {
        "There are \(count) configured homes with an item named '\(item)'."
    }

    static func homeParameterConfirmation(home: Home) -> Self {
        "Just to confirm, you wanted '\(home)'?"
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
