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

enum ItemStateError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct GetItemStateIntent: AppIntent {
    static var openAppWhenRun: Bool {
        false
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$itemEntity) State") {
            \.$home
        }
    }

    static let title: LocalizedStringResource = "Get Item State"
    static let description = IntentDescription("Retrieve the current state of an item", resultValueName: "State")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("Search for an item")
    )
    var itemEntity: GenericItemEntity

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        await Preferences.prepareForAppExtensionAccess()

        // Validate that the item belongs to the selected home
        let homeId = try await HomeResolver.resolvedHomeId(
            selectedHome: home,
            itemHomeId: itemEntity.homeId,
            itemLabel: itemEntity.label,
            mismatchError: ItemStateError.itemNotInHome
        )

        let freshItem = await OpenHABItemCache.instance.getItemUncached(name: itemEntity.itemName, home: homeId)
        let state = freshItem?.state ?? itemEntity.item.state ?? "Unknown state"

        return .result(
            value: state,
            dialog: "The state of \(itemEntity.label) is \(state)"
        )
    }
}
