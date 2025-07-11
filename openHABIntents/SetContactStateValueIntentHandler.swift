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

class SetContactStateValueIntentHandler: NSObject, OpenHABSetContactStateValueIntentHandling {
    func resolveHome(for intent: OpenHABSetContactStateValueIntent) async -> INStringResolutionResult {
        // TODO:
        INStringResolutionResult.success(with: intent.home ?? "Home")
    }

    func provideHomeOptionsCollection(for intent: OpenHABSetContactStateValueIntent) async throws -> INObjectCollection<NSString> {
        await INObjectCollection(items: Preferences.storedHomes.map(\.value.homeName).map { $0 as NSString })
    }

    private static let onLabel = NSLocalizedString("on", comment: "").capitalized
    private static let offLabel = NSLocalizedString("off", comment: "").capitalized

    private static let localizedActions = [onLabel, offLabel]
    private static let actionMap: [String: String] = [
        onLabel: "ON",
        offLabel: "OFF"
    ]

    private let logger = Logger(subsystem: "org.openhab.app", category: "SetColorValueIntent")
    private let itemCache: any ItemCacheProtocol

    init(itemCache: any ItemCacheProtocol = OpenHABItemCache.instance) {
        self.itemCache = itemCache
    }

    func provideStateOptionsCollection(for intent: OpenHABSetContactStateValueIntent) async throws -> INObjectCollection<NSString> {
        INObjectCollection(items: Self.localizedActions as [NSString])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetContactStateValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        let items = await itemCache
            .getItemNames(searchTerm: searchTerm, types: [.contact])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetContactStateValueIntent) async throws -> INObjectCollection<NSString> {
        let items = await itemCache
            .getItemNames(searchTerm: nil, types: [.contact])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func confirm(intent: OpenHABSetContactStateValueIntent) async -> OpenHABSetContactStateValueIntentResponse {
        OpenHABSetContactStateValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetContactStateValueIntent) async -> OpenHABSetContactStateValueIntentResponse {
        logger.info("SetContactStateValueIntent for \(intent.item ?? "")")

        await OpenHABItemCache.instance.waitUntilReady()

        guard let itemName = intent.item else {
            return .failureInvalidItem(NSLocalizedString("empty", comment: "empty item name"))
        }

        guard let state = intent.state else {
            return .failureInvalidAction(
                state: NSLocalizedString("empty", comment: "empty value"),
                item: itemName
            )
        }

        guard let realState = Self.actionMap[state] else {
            return .failureInvalidAction(state: state, item: itemName)
        }

        guard let item = await itemCache.getItem(name: itemName) else {
            return .failureInvalidItem(itemName)
        }

        await itemCache.sendState(item, stateToSend: realState)

        return .success(item: itemName, state: state)
    }
}
