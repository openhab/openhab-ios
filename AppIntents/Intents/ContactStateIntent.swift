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
import Intents
import OpenHABCore

enum ContactStateError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ContactStateIntent: AppIntent {
    static var allowedItemTypes: [OpenHABItem.ItemType] { [.contact] }

    static var parameterSummary: some ParameterSummary {
        Summary("Set the state of \(\.$itemEntity) to \(\.$state)") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Set Contact State Value"
    static let description = IntentDescription("Set the state of a contact open or closed")

    @Parameter(title: "Home")
    var home: Home

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("Search for an item")
    )
    var itemEntity: ContactItemEntity

    @Parameter(title: "State")
    var state: ContactState

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Validate that the item belongs to the selected home
        guard let homeId = UUID(uuidString: home.id), homeId == itemEntity.homeId else {
            throw ContactStateError.itemNotInHome(itemEntity.label, home.displayString)
        }

        await OpenHABItemCache.instance.sendCommand(
            to: itemEntity.item,
            home: itemEntity.homeId,
            command: state.rawValue
        )

        return .result(dialog: "The state of \(itemEntity.label) was set to \(state.rawValue)")
    }
}
