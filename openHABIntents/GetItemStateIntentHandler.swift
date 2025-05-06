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

class GetItemStateIntentHandler: NSObject, OpenHABGetItemStateIntentHandling {
    private let logger = Logger(subsystem: "org.openhab.app", category: "GetItemStateIntent")
    private let itemCache: ItemCacheProtocol

    init(itemCache: ItemCacheProtocol = OpenHABItemCache.instance) {
        self.itemCache = itemCache
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        let items = await itemCache.getItemNames(searchTerm: searchTerm, types: nil).map(NSString.init)
        return INObjectCollection(items: items)
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent) async throws -> INObjectCollection<NSString> {
        let items = await itemCache.getItemNames(searchTerm: nil, types: nil).map(NSString.init)
        return INObjectCollection(items: items)
    }

    func confirm(intent: OpenHABGetItemStateIntent) async -> OpenHABGetItemStateIntentResponse {
        OpenHABGetItemStateIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABGetItemStateIntent) async -> OpenHABGetItemStateIntentResponse {
        logger.info("GetItemStateIntent for \(intent.item ?? "")")
        await OpenHABItemCache.instance.waitUntilReady()
        // Proceed to fetch item and complete

        guard let itemName = intent.item else {
            return .failureInvalidItem(
                NSLocalizedString("empty", comment: "empty item name")
            )
        }

        let item = await itemCache.getItem(name: itemName)

        guard let item else {
            return .failureInvalidItem(itemName)
        }

        return .success(
            item: itemName,
            state: item.state ?? NSLocalizedString("unknown", comment: "unknown item")
        )
    }
}
