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

enum NumberValueError: Error, CustomLocalizedStringResourceConvertible {
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

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SetNumberValueIntent: AppIntent {
    static var openAppWhenRun: Bool { false }

    static var allowedItemTypes: [OpenHABItem.ItemType] { [.number, .numberWithDimension] }
    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$itemEntity) to \(\.$value)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set Number Control Value"
    static let description = IntentDescription("Set the decimal value of a number control item")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("Search for an item")
    )
    var itemEntity: NumberItemEntity

    @Parameter(title: "Value")
    var value: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Preferences.prepareForAppExtensionAccess()

        // Validate that the item belongs to the selected home
        let homeId = try await HomeResolver.resolvedHomeId(
            selectedHome: home,
            itemHomeId: itemEntity.homeId,
            itemLabel: itemEntity.label,
            mismatchError: NumberValueError.itemNotInHome
        )

        do {
            try await OpenHABItemCache.instance.sendCommand(
                to: itemEntity.item,
                home: homeId,
                command: NumberState(value: value).commandString
            )
        } catch {
            throw NumberValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: "Sent the number \(value) to \(itemEntity.label)")
    }
}
