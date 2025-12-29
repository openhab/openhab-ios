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

enum StringValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct StringValueIntent: AppIntent {
    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$itemEntity) to \(\.$value)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set String Control Value"
    static let description = IntentDescription("Set the string of a string control item")

    @Parameter(title: "Home")
    var home: Home

    @Parameter(title: "Item", requestValueDialog: IntentDialog("Search for an item"))
    var itemEntity: ItemAppEntity

    @Parameter(title: "Value")
    var value: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Validate that the item belongs to the selected home
        guard let homeId = UUID(uuidString: home.id), homeId == itemEntity.homeId else {
            throw StringValueError.itemNotInHome(itemEntity.label, home.displayString)
        }

        await OpenHABItemCache.instance.sendCommand(
            to: itemEntity.item,
            home: itemEntity.homeId,
            command: value
        )

        return .result(dialog: "Sent the string \(value) to \(itemEntity.label)")
    }
}
