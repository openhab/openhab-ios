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
import os

final class SetSwitchStateIntentHandler: NSObject, OpenHABSetSwitchStateIntentHandling {
    private static let onLabel = String(localized: "on", comment: "").capitalized
    private static let offLabel = String(localized: "off", comment: "").capitalized

    private static let localizedActions = [onLabel, offLabel]
    private static let actionMap: [String: String] = [
        onLabel: "ON",
        offLabel: "OFF"
    ]

    func resolveHome(for intent: OpenHABSetSwitchStateIntent) async -> OpenHABHomeResolutionResult {
        Logger.intentHandling.info("Resolving home for intent: \(intent)")
        return await OpenHABIntentHelper.resolveHome(home: intent.home, item: intent.item)
    }

    func provideHomeOptionsCollection(for intent: OpenHABSetSwitchStateIntent) async throws -> INObjectCollection<OpenHABHome> {
        await OpenHABIntentHelper.getHomeOptions()
    }

    func provideActionOptionsCollection(for intent: OpenHABSetSwitchStateIntent) async throws -> INObjectCollection<NSString> {
        Logger.intentHandling.info("SetSwitchStateIntentHandler provideActionOptionsCollection")
        return INObjectCollection(items: Self.localizedActions as [NSString])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        Logger.intentHandling.info("SetSwitchStateIntentHandler provideItemOptionsCollection with searchTerm: \(searchTerm ?? "<none>", privacy: .public)")
        return await OpenHABIntentHelper.getItemOptions(home: intent.home, searchTerm: searchTerm, itemTypes: [.switchItem])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent) async throws -> INObjectCollection<NSString> {
        Logger.intentHandling.info("SetSwitchStateIntentHandler provideItemOptionsCollection")
        return await OpenHABIntentHelper.getItemOptions(home: intent.home, itemTypes: [.switchItem])
    }

    func confirm(intent: OpenHABSetSwitchStateIntent) async -> OpenHABSetSwitchStateIntentResponse {
        .init(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetSwitchStateIntent) async -> OpenHABSetSwitchStateIntentResponse {
        Logger.intentHandling.info("SetSwitchStateIntent for item: \(intent.item ?? "<none>", privacy: .public)")

        guard let itemName = intent.item, let home = intent.home else {
            return .failureInvalidItem(
                String(localized: "empty", comment: "empty item / home name")
            )
        }

        guard let homeId = home.uuid, await Preferences.shared.storedHomes[homeId] != nil else {
            return .failureInvalidItem(String(localized: "unknownHome", comment: "unknown home"))
        }

        guard !itemName.isEmpty else {
            return .failureInvalidItem(String(localized: "empty", comment: "empty item name"))
        }

        guard let action = intent.action else {
            return .failureInvalidAction(String(localized: "empty", comment: "empty action"), item: itemName)
        }

        guard let command = Self.actionMap[action] else {
            return .failureInvalidAction(action, item: itemName)
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: itemName, home: homeId), !items.isEmpty else {
            return .failureInvalidItem(itemName)
        }

        let item = items[0]

        await OpenHABItemCache.instance.sendCommand(to: item, home: homeId, command: command)
        return .success(action: action, item: itemName)
    }
}
