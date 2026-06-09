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

// MARK: - Item state localization

/// Wraps a raw openHAB state string so that well-known binary states
/// (ON/OFF, OPEN/CLOSED, player commands) are displayed in the user's
/// language inside Shortcuts dialogs, while numeric or custom states
/// pass through unchanged.
@available(iOS 17.0, macOS 14.0, *)
private struct LocalizedItemState: CustomLocalizedStringResourceConvertible {
    let rawValue: String

    var localizedStringResource: LocalizedStringResource {
        let upper = rawValue.uppercased()
        if let action = SwitchAction(rawValue: upper) {
            return action.localizedStringResource
        }
        if let contact = ContactState(rawValue: upper) {
            return contact.localizedStringResource
        }
        if let player = PlayerAction(rawValue: upper) {
            return player.localizedStringResource
        }
        // Numeric states, HSB color values, temperatures, etc.: pass through as-is.
        // The static key is intentionally absent from the strings catalog so the
        // defaultValue (the raw state) is always used.
        return LocalizedStringResource("__item_state_passthrough__", defaultValue: "\(rawValue)")
    }
}

// MARK: -

enum ItemStateError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotInHome(String, String)
    case itemNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotInHome(itemName, homeName):
            "Item '\(itemName)' is not in home '\(homeName)'"
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
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
    static let description = IntentDescription("Retrieve the current state of an item")

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

        guard let item = await OpenHABItemCache.instance.getItemUncached(name: itemEntity.itemName, home: homeId) else {
            throw ItemStateError.itemNotFound(itemEntity.itemName)
        }
        let rawState = item.state ?? "Unknown state"

        // Prefer the server-formatted state, then fall back to local number formatting,
        // then fall back to the raw state string.
        let displayState: String = if let transformed = item.transformedState, !transformed.isEmpty {
            transformed
        } else if let pattern = item.stateDescription?.numberPattern,
                  Double(rawState.components(separatedBy: " ").first ?? "") != nil {
            rawState.parseAsNumber(format: pattern).toString(locale: .current)
        } else {
            rawState
        }

        let stateDisplay = LocalizedItemState(rawValue: displayState)

        return .result(
            value: displayState,
            dialog: "The state of \(itemEntity.label) is \(stateDisplay)"
        )
    }
}
