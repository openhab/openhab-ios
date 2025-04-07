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

import Foundation
import Intents
import OpenHABCore
import os

final class SetSwitchStateIntentHandler: NSObject, OpenHABSetSwitchStateIntentHandling {
    private static let onLabel = NSLocalizedString("on", comment: "").capitalized
    private static let offLabel = NSLocalizedString("off", comment: "").capitalized

    private static let localizedActions = [onLabel, offLabel]
    private static let actionMap: [String: String] = [
        onLabel: "ON",
        offLabel: "OFF"
    ]

    private let logger = Logger(subsystem: "org.openhab.app", category: "SetSwitchStateIntent")

    private let itemCache: ItemCacheProtocol

    init(itemCache: ItemCacheProtocol = OpenHABItemCache.instance) {
        self.itemCache = itemCache
    }

    func provideActionOptionsCollection(for intent: OpenHABSetSwitchStateIntent) async throws -> INObjectCollection<NSString> {
        logger.info("SetSwitchStateIntentHandler provideActionOptionsCollection")
        return INObjectCollection(items: Self.localizedActions as [NSString])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        logger.info("SetSwitchStateIntentHandler provideItemOptionsCollection with searchTerm: \(searchTerm ?? "<none>", privacy: .public)")

        let itemNames = await itemCache
            .getItemNames(
                searchTerm: searchTerm,
                types: [.switchItem]
            )
            .map(NSString.init)

        return INObjectCollection(items: itemNames)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent) async throws -> INObjectCollection<NSString> {
        logger.info("SetSwitchStateIntentHandler provideItemOptionsCollection")

        return try await provideItemOptionsCollection(for: intent, searchTerm: nil)
    }

    func confirm(intent: OpenHABSetSwitchStateIntent) async -> OpenHABSetSwitchStateIntentResponse {
        .init(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetSwitchStateIntent) async -> OpenHABSetSwitchStateIntentResponse {
        let itemName = intent.item ?? ""
        logger.info("SetSwitchStateIntent for item: \(intent.item ?? "<none>", privacy: .public)")

        guard !itemName.isEmpty else {
            return .failureInvalidItem(NSLocalizedString("empty", comment: "empty item name"))
        }

        guard let action = intent.action else {
            return .failureInvalidAction(NSLocalizedString("empty", comment: "empty action"), item: itemName)
        }

        guard let command = Self.actionMap[action] else {
            return .failureInvalidAction(action, item: itemName)
        }

        guard let item = await itemCache.getItem(name: itemName) else {
            return .failureInvalidItem(itemName)
        }

        await itemCache.sendCommand(item, commandToSend: command)
        return .success(action: action, item: itemName)
    }
}
