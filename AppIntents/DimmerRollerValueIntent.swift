// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import Intents
import OpenHABCore

enum DimmerRollerValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)
    case invalidValue(Int, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        case let .invalidValue(value, itemName):
            "Invalid value \(value) for \(itemName) (0-100)"
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct DimmerRollerValueIntent: AppIntent {
    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$itemEntity) to \(\.$value)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set Dimmer or Roller Shutter Value"
    static let description = IntentDescription("Set the integer value of a dimmer or roller shutter")

    @Parameter(title: "Home")
    var home: Home

    @Parameter(title: "Item", requestValueDialog: IntentDialog("Search for an item"))
    var itemEntity: ItemAppEntity

    @Parameter(title: "Value")
    var value: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Validate that the item belongs to the selected home
        guard let homeId = UUID(uuidString: home.id), homeId == itemEntity.homeId else {
            throw DimmerRollerValueError.itemNotInHome(itemEntity.label, home.displayString)
        }

        guard (0 ... 100).contains(value) else {
            throw DimmerRollerValueError.invalidValue(value, itemEntity.label)
        }

        await OpenHABItemCache.instance.sendCommand(
            to: itemEntity.item,
            home: itemEntity.homeId,
            command: "\(value)"
        )

        return .result(dialog: "Sent the value of \(value) to \(itemEntity.label)")
    }
}
