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

    func provideActionOptionsCollection(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        let collection = INObjectCollection(items: Self.localizedActions as [NSString])
        completion(collection, nil)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        Task {
            let itemNames = await self.itemCache.getItemNames(
                searchTerm: searchTerm,
                types: [.switchItem]
            ).map(NSString.init)

            completion(INObjectCollection(items: itemNames), nil)
        }
    }

    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        provideItemOptionsCollection(for: intent, searchTerm: nil, with: completion)
    }

    func confirm(intent: OpenHABSetSwitchStateIntent, completion: @escaping (OpenHABSetSwitchStateIntentResponse) -> Void) {
        completion(.init(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABSetSwitchStateIntent, completion: @escaping (OpenHABSetSwitchStateIntentResponse) -> Void) {
        let itemName = intent.item ?? ""
        logger.info("SetSwitchStateIntent for item: \(intent.item ?? "<none>", privacy: .public)")

        guard !itemName.isEmpty else {
            completion(.failureInvalidItem(NSLocalizedString("empty", comment: "empty item name")))
            return
        }

        guard let action = intent.action else {
            completion(.failureInvalidAction(NSLocalizedString("empty", comment: "empty action"), item: itemName))
            return
        }

        guard let command = Self.actionMap[action] else {
            completion(.failureInvalidAction(action, item: itemName))
            return
        }

        Task {
            guard let item = await itemCache.getItem(name: itemName) else {
                completion(.failureInvalidItem(itemName))
                return
            }

            await itemCache.sendCommand(item, commandToSend: command)
            completion(.success(action: action, item: itemName))
        }
    }
}
