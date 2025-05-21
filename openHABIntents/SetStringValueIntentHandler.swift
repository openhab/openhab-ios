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

class SetStringValueIntentHandler: NSObject, OpenHABSetStringValueIntentHandling {
    private let logger = Logger(subsystem: "org.openhab.app", category: "SetStringValueIntent")
    private let itemCache: any ItemCacheProtocol

    init(itemCache: any ItemCacheProtocol = OpenHABItemCache.instance) {
        self.itemCache = itemCache
    }

    func provideItemOptionsCollection(for intent: OpenHABSetStringValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        let items = await itemCache
            .getItemNames(searchTerm: searchTerm, types: [.stringItem])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetStringValueIntent) async throws -> INObjectCollection<NSString> {
        let items = await itemCache
            .getItemNames(searchTerm: nil, types: [.stringItem])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func confirm(intent: OpenHABSetStringValueIntent) async -> OpenHABSetStringValueIntentResponse {
        OpenHABSetStringValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetStringValueIntent) async -> OpenHABSetStringValueIntentResponse {
        logger.info("SetStringValueIntent for \(intent.item ?? "")")

        await OpenHABItemCache.instance.waitUntilReady()

        guard let itemName = intent.item else {
            return .failureInvalidItem(
                NSLocalizedString("empty", comment: "empty item name")
            )
        }

        guard let value = intent.value else {
            return .failureEmptyValue(item: itemName)
        }

        guard let item = await itemCache.getItem(name: itemName) else {
            return .failureInvalidItem(itemName)
        }

        await itemCache.sendCommand(item, commandToSend: value)

        return .success(value: value, item: itemName)
    }
}
