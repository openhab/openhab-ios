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

enum ControlItemError: Error, CustomLocalizedStringResourceConvertible {
    case invalidAction(String, String)
    case itemNotInHome(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .invalidAction(action, itemName):
            "Action invalid: \(action) for \(itemName)"
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SwitchStateIntent: AppIntent {
    static var allowedItemTypes: [OpenHABItem.ItemType] { [.switchItem] }
    struct ActionOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            ActionMapper.onOffToggleOptions
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$itemEntity)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set Switch State"
    static let description = IntentDescription("Set the state of a switch on or off, or toggle its state")

    @Parameter(title: "Home")
    var home: Home

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("Search for an item")
    )
    var itemEntity: SwitchItemEntity

    @Parameter(title: "Action", optionsProvider: ActionOptionsProvider())
    var action: String

    func perform() async throws -> some IntentResult {
        // Validate that the item belongs to the selected home
        guard let homeId = UUID(uuidString: home.id), homeId == itemEntity.homeId else {
            throw ControlItemError.itemNotInHome(itemEntity.label, home.displayString)
        }

        guard let command = ActionMapper.command(from: action) else {
            throw ControlItemError.invalidAction(action, itemEntity.label)
        }

        await OpenHABItemCache.instance.sendCommand(
            to: itemEntity.item,
            home: itemEntity.homeId,
            command: command
        )

        return .result()
    }
}
