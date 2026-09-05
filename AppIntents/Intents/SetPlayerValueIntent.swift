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

enum PlayerValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

struct SetPlayerValueIntent: AppIntent {
    static var openAppWhenRun: Bool {
        false
    }

    static var allowedItemTypes: [OpenHABItem.ItemType] {
        [.player]
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$itemEntity)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set Player Control Value"
    static let description = IntentDescription("Send a player command such as play, pause, next, or previous")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("Search for an item")
    )
    var itemEntity: PlayerItemEntity

    @Parameter(title: "Action")
    var action: PlayerAction

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Preferences.prepareForAppExtensionAccess()

        let homeId = try await HomeResolver.resolvedHomeId(
            selectedHome: home,
            itemHomeId: itemEntity.homeId,
            itemLabel: itemEntity.label,
            mismatchError: PlayerValueError.itemNotInHome
        )

        do {
            try await OpenHABItemCache.instance.sendCommand(
                to: itemEntity.item,
                home: homeId,
                command: action.rawValue
            )
        } catch {
            throw PlayerValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: "Sent \(action.rawValue) to \(itemEntity.label)")
    }
}
