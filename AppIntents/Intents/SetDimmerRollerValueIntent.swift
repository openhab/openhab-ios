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

enum DimmerRollerValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)
    case invalidValue(Int, String)
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        case let .invalidValue(value, itemName):
            "Invalid value \(value) for \(itemName) (0-100)"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

struct SetDimmerRollerValueIntent: AppIntent {
    static var openAppWhenRun: Bool { false }

    static var allowedItemTypes: [OpenHABItem.ItemType] { [.dimmer, .rollershutter] }
    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$itemEntity) to \(\.$value)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set Dimmer or Roller Shutter Value"
    static let description = IntentDescription("Set the integer value of a dimmer or roller shutter")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("Search for an item")
    )
    var itemEntity: DimmerItemEntity

    @Parameter(title: "Value")
    var value: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Preferences.prepareForAppExtensionAccess()

        // Validate that the item belongs to the selected home
        let homeId = try await HomeResolver.resolvedHomeId(
            selectedHome: home,
            itemHomeId: itemEntity.homeId,
            itemLabel: itemEntity.label,
            mismatchError: DimmerRollerValueError.itemNotInHome
        )

        guard (0 ... 100).contains(value) else {
            throw DimmerRollerValueError.invalidValue(value, itemEntity.label)
        }

        do {
            try await OpenHABItemCache.instance.sendCommand(
                to: itemEntity.item,
                home: homeId,
                command: "\(value)"
            )
        } catch {
            throw DimmerRollerValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: "Sent the value of \(value) to \(itemEntity.label)")
    }
}
