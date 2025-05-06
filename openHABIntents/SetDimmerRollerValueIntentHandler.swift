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
import os.log

class SetDimmerRollerValueIntentHandler: NSObject, OpenHABSetDimmerRollerValueIntentHandling {
    private let logger = Logger(subsystem: "org.openhab.app", category: "SetDimmerRollerValueIntent")
    private let itemCache: ItemCacheProtocol

    init(itemCache: ItemCacheProtocol = OpenHABItemCache.instance) {
        self.itemCache = itemCache
    }

    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        let items = await itemCache.getItemNames(
            searchTerm: searchTerm,
            types: [.dimmer, .rollershutter]
        )
        .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent) async throws -> INObjectCollection<NSString> {
        let items = await itemCache.getItemNames(
            searchTerm: nil,
            types: [.dimmer, .rollershutter]
        )
        .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func confirm(intent: OpenHABSetDimmerRollerValueIntent) async -> OpenHABSetDimmerRollerValueIntentResponse {
        OpenHABSetDimmerRollerValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetDimmerRollerValueIntent) async -> OpenHABSetDimmerRollerValueIntentResponse {
        logger.info("SetDimmerRollerValueIntent for \(intent.item ?? "")")

        await OpenHABItemCache.instance.waitUntilReady()

        guard let itemName = intent.item else {
            return .failureInvalidItem(
                NSLocalizedString("empty", comment: "empty item name")
            )
        }

        guard let value = intent.value else {
            return .failureEmptyValue(item: itemName)
        }

        let number = Int(truncating: value)

        guard (0 ... 100).contains(number) else {
            return .failureInvalidValue(value, item: itemName)
        }

        guard let item = await itemCache.getItem(name: itemName) else {
            return .failureInvalidItem(itemName)
        }

        await itemCache.sendCommand(item, commandToSend: "\(number)")

        return .success(value: NSNumber(value: number), item: itemName)
    }
}
