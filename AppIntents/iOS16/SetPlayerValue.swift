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
import Foundation
import OpenHABCore

@available(iOS, introduced: 16.0, obsoleted: 17.0)
enum SetPlayerValueError: Error, CustomLocalizedStringResourceConvertible {
    case itemNotFound(String)
    case invalidAction(String, String)
    case commandFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .itemNotFound(itemName):
            "Item '\(itemName)' not found"
        case let .invalidAction(action, itemName):
            "Action invalid: \(action) for \(itemName)"
        case let .commandFailed(message):
            "Command failed: \(message)"
        }
    }
}

@available(iOS, introduced: 16.0, obsoleted: 17.0, message: "Use SetPlayerValueIntent for iOS 17+")
struct SetPlayerValue: AppIntent, PredictableIntent {
    // swiftlint:disable type_contents_order

    static let title: LocalizedStringResource = "Set Player Control Value"
    static let description = IntentDescription("Send a player command such as play, pause, next, or previous")

    @Parameter(title: "Home")
    var home: Home?

    struct ItemOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let items = allItems.flatMap(\.value).filter { $0.type == .player }
            return items.map(\.name)
        }
    }

    @Parameter(title: "Item", optionsProvider: ItemOptionsProvider())
    var item: String

    struct ActionOptionsProvider: DynamicOptionsProvider {
        func results() throws -> [String] {
            ["Play", "Pause", "Next", "Previous", "Rewind", "Fast Forward"]
        }
    }

    @Parameter(title: "Action", optionsProvider: ActionOptionsProvider())
    var action: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$action) to \(\.$item)") {
            \.$home
        }
    }

    // swiftlint:enable type_contents_order

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$item, \.$action, \.$home)) { item, action, _ in
            DisplayRepresentation(
                title: "Send \(action) to \(item)",
                subtitle: ""
            )
        }
    }

    private static let actionMap: [String: String] = [
        "Play": "PLAY",
        "Pause": "PAUSE",
        "Next": "NEXT",
        "Previous": "PREVIOUS",
        "Rewind": "REWIND",
        "Fast Forward": "FASTFORWARD"
    ]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let homeId = try await HomeResolver.resolveHomeId(
            selectedHome: home,
            itemName: item,
            allowedTypes: [.player]
        )

        guard let command = Self.actionMap[action] else {
            throw SetPlayerValueError.invalidAction(action, item)
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: item, home: homeId),
              !items.isEmpty else {
            throw SetPlayerValueError.itemNotFound(item)
        }

        let openHABItem = items[0]

        do {
            try await OpenHABItemCache.instance.sendCommand(to: openHABItem, home: homeId, command: command)
        } catch {
            throw SetPlayerValueError.commandFailed(error.localizedDescription)
        }

        return .result(dialog: "Sent the action of \(action) to player \(item)")
    }
}
