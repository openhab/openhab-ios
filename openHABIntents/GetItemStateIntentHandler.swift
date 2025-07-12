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
    func resolveHome(for intent: OpenHABGetItemStateIntent) async -> INStringResolutionResult {
        // TODO: better (fuzzy?) resolution of home name
        logger.info("Resolving home for intent: \(intent)")
        return await OpenHABIntentHelper.resolveHome(home: intent.home, item: intent.item)
    }

    func provideHomeOptionsCollection(for intent: OpenHABGetItemStateIntent) async throws -> INObjectCollection<NSString> {
        INObjectCollection(items: Preferences.storedHomes.map(\.value.homeName).map { $0 as NSString })
    }

    private let logger = Logger(subsystem: "org.openhab.app", category: "GetItemStateIntent")
    private let itemCache: OpenHABItemCache

    init(itemCache: OpenHABItemCache = OpenHABItemCache.instance) {
        self.itemCache = itemCache
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        let items = await itemCache.getAllCachedItems().flatMap(\.value).filtered(by: searchTerm)
        return INObjectCollection(items: items.map(\.name).map { $0 as NSString })
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent) async throws -> INObjectCollection<NSString> {
        let items = await itemCache.getAllCachedItems().flatMap(\.value)
        return INObjectCollection(items: items.map(\.name).map { $0 as NSString })
    }

    func confirm(intent: OpenHABGetItemStateIntent) async -> OpenHABGetItemStateIntentResponse {
        OpenHABGetItemStateIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABGetItemStateIntent) async -> OpenHABGetItemStateIntentResponse {
        logger.info("GetItemStateIntent for \(intent.item ?? "")")

        guard let itemName = intent.item, let homeName = intent.home else {
            return .failureInvalidItem(
                NSLocalizedString("empty", comment: "empty item / home name")
            )
        }

        let homeIds = Preferences.storedHomes.values.filter { $0.homeName == homeName }.map(\.id)
        guard homeIds.count == 1 else {
            return .failureInvalidItem(NSLocalizedString("unknownHome", comment: "unknown home"))
        }

        let items = await itemCache.getCachedItem(name: itemName, home: homeIds[0])

        guard let items, items.count == 1 else {
            return .failureInvalidItem(itemName)
        }

        return .success(
            item: itemName,
            state: items[0].state ?? NSLocalizedString("unknown", comment: "unknown item")
        )
    }
}
