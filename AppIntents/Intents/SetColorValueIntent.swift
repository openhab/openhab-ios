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
import OpenHABCore

enum ColorValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)
    case invalidValue(String, String)
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        case let .invalidValue(value, itemName):
            "Invalid value: \(value) for \(itemName) must be HSB (0-360,0-100,0-100)"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

struct SetColorValueIntent: AppIntent {
    static var openAppWhenRun: Bool {
        false
    }

    static var allowedItemTypes: [OpenHABItem.ItemType] {
        [.color]
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$itemEntity) to \(\.$value) (HSB)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set Color Control Value"
    static let description = IntentDescription("Set the color of a color control item")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("Search for an item")
    )
    var itemEntity: ColorItemEntity

    @Parameter(title: "Value", default: "240,100,100")
    var value: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Preferences.prepareForAppExtensionAccess()

        // Validate that the item belongs to the selected home
        let homeId = try await HomeResolver.resolvedHomeId(
            selectedHome: home,
            itemHomeId: itemEntity.homeId,
            itemLabel: itemEntity.label,
            mismatchError: ColorValueError.itemNotInHome
        )

        let hsb = value.split(separator: ",")
        guard hsb.count == 3,
              let hue = Int(hsb[0]), (0 ... 360).contains(hue),
              let sat = Int(hsb[1]), (0 ... 100).contains(sat),
              let val = Int(hsb[2]), (0 ... 100).contains(val) else {
            throw ColorValueError.invalidValue(value, itemEntity.label)
        }

        let colorValue = "\(hue),\(sat),\(val)"

        do {
            try await OpenHABItemCache.instance.sendCommand(
                to: itemEntity.item,
                home: homeId,
                command: colorValue
            )
        } catch {
            throw ColorValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: "Sent the color value of \(colorValue) to \(itemEntity.label)")
    }
}
