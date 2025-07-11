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

class SetNumberValueIntentHandler: NSObject, OpenHABSetNumberValueIntentHandling {
    func resolveHome(for intent: OpenHABSetNumberValueIntent) async -> INStringResolutionResult {
        // TODO:
        INStringResolutionResult.success(with: intent.home ?? "Home")
    }

    func provideHomeOptionsCollection(for intent: OpenHABSetNumberValueIntent) async throws -> INObjectCollection<NSString> {
        await INObjectCollection(items: Preferences.storedHomes.map(\.value.homeName).map { $0 as NSString })
    }

    private let logger = Logger(subsystem: "org.openhab.app", category: "SetNumberValueIntent")
    private let itemCache: any ItemCacheProtocol

    init(itemCache: any ItemCacheProtocol = OpenHABItemCache.instance) {
        self.itemCache = itemCache
    }

    func provideItemOptionsCollection(for intent: OpenHABSetNumberValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        let items = await itemCache
            .getItemNames(searchTerm: searchTerm, types: [.number])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetNumberValueIntent) async throws -> INObjectCollection<NSString> {
        let items = await itemCache
            .getItemNames(searchTerm: nil, types: [.number])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func confirm(intent: OpenHABSetNumberValueIntent) async -> OpenHABSetNumberValueIntentResponse {
        OpenHABSetNumberValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetNumberValueIntent) async -> OpenHABSetNumberValueIntentResponse {
        logger.info("SetNumberValueIntent for \(intent.item ?? "")")

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

        await itemCache.sendCommand(item, commandToSend: value.stringValue)

        return .success(value: value, item: itemName)
    }
}
