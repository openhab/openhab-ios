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

import Foundation
import Intents
import OpenHABCore
import os.log

class SetContactStateValueIntentHandler: NSObject, OpenHABSetContactStateValueIntentHandling {
    private static let onLabel = String(localized: "on", comment: "").capitalized
    private static let offLabel = String(localized: "off", comment: "").capitalized

    private static let localizedActions = [onLabel, offLabel]
    private static let actionMap: [String: String] = [
        onLabel: "ON",
        offLabel: "OFF"
    ]

    func resolveHome(for intent: OpenHABSetContactStateValueIntent) async -> OpenHABHomeResolutionResult {
        Logger.intentHandling.info("Resolving home for intent: \(intent)")
        return await OpenHABIntentHelper.resolveHome(home: intent.home, item: intent.item)
    }

    func provideHomeOptionsCollection(for intent: OpenHABSetContactStateValueIntent) async throws -> INObjectCollection<OpenHABHome> {
        await OpenHABIntentHelper.getHomeOptions()
    }

    func provideStateOptionsCollection(for intent: OpenHABSetContactStateValueIntent) async throws -> INObjectCollection<NSString> {
        INObjectCollection(items: Self.localizedActions as [NSString])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetContactStateValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, searchTerm: searchTerm, itemTypes: [.contact])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetContactStateValueIntent) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, itemTypes: [.contact])
    }

    func confirm(intent: OpenHABSetContactStateValueIntent) async -> OpenHABSetContactStateValueIntentResponse {
        OpenHABSetContactStateValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetContactStateValueIntent) async -> OpenHABSetContactStateValueIntentResponse {
        Logger.intentHandling.info("SetContactStateValueIntent for \(intent.item ?? "")")

        guard let itemName = intent.item, let home = intent.home else {
            return .failureInvalidItem(
                String(localized: "empty", comment: "empty item / home name")
            )
        }

        guard let homeId = home.uuid, await Preferences.shared.storedHomes[homeId] != nil else {
            return .failureInvalidItem(String(localized: "unknownHome", comment: "unknown home"))
        }

        guard let state = intent.state else {
            return .failureInvalidAction(
                state: String(localized: "empty", comment: "empty value"),
                item: itemName
            )
        }

        guard let realState = Self.actionMap[state] else {
            return .failureInvalidAction(state: state, item: itemName)
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: itemName, home: homeId), !items.isEmpty else {
            return .failureInvalidItem(itemName)
        }

        let item = items[0]

        await OpenHABItemCache.instance.sendCommand(to: item, home: homeId, command: realState)

        return .success(item: itemName, state: state)
    }
}
