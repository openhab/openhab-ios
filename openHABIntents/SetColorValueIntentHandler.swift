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

class SetColorValueIntentHandler: NSObject, OpenHABSetColorValueIntentHandling {
    private let logger = Logger(subsystem: "org.openhab.app", category: "SetColorValueIntent")
    private let itemCache: ItemCacheProtocol

    init(itemCache: ItemCacheProtocol = OpenHABItemCache.instance) {
        self.itemCache = itemCache
    }

    func provideItemOptionsCollection(for intent: OpenHABSetColorValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        let items = await itemCache
            .getItemNames(searchTerm: searchTerm, types: [.color])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetColorValueIntent) async throws -> INObjectCollection<NSString> {
        let items = await itemCache
            .getItemNames(searchTerm: nil, types: [.color])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func confirm(intent: OpenHABSetColorValueIntent) async -> OpenHABSetColorValueIntentResponse {
        OpenHABSetColorValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetColorValueIntent) async -> OpenHABSetColorValueIntentResponse {
        logger.info("SetColorValueIntent for \(intent.item ?? "")")

        await OpenHABItemCache.instance.waitUntilReady()

        guard let itemName = intent.item else {
            return .failureInvalidItem(NSLocalizedString("empty", comment: "empty item name"))
        }

        guard var value = intent.value else {
            return .failureInvalidValue(
                NSLocalizedString("empty", comment: "empty value"),
                item: itemName
            )
        }

        let hsb = value.split(separator: ",")
        guard hsb.count == 3,
              let hue = Int(hsb[0]), (0 ... 360).contains(hue),
              let sat = Int(hsb[1]), (0 ... 100).contains(sat),
              let val = Int(hsb[2]), (0 ... 100).contains(val) else {
            return .failureInvalidValue(value, item: itemName)
        }

        value = "\(hue),\(sat),\(val)"

        guard let item = await itemCache.getItem(name: itemName) else {
            return .failureInvalidItem(itemName)
        }

        await itemCache.sendCommand(item, commandToSend: value)

        return .success(value: value, item: itemName)
    }
}
