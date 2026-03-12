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
import os.log

class SetNumberValueIntentHandler: NSObject, OpenHABSetNumberValueIntentHandling {
    func resolveHome(for intent: OpenHABSetNumberValueIntent) async -> OpenHABHomeResolutionResult {
        Logger.intentHandling.info("Resolving home for intent: \(intent)")
        return await OpenHABIntentHelper.resolveHome(home: intent.home, item: intent.item)
    }

    func provideHomeOptionsCollection(for intent: OpenHABSetNumberValueIntent) async throws -> INObjectCollection<OpenHABHome> {
        await OpenHABIntentHelper.getHomeOptions()
    }

    func provideItemOptionsCollection(for intent: OpenHABSetNumberValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, searchTerm: searchTerm, itemTypes: [.number])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetNumberValueIntent) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, itemTypes: [.number])
    }

    func confirm(intent: OpenHABSetNumberValueIntent) async -> OpenHABSetNumberValueIntentResponse {
        OpenHABSetNumberValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetNumberValueIntent) async -> OpenHABSetNumberValueIntentResponse {
        Logger.intentHandling.info("SetNumberValueIntent for \(intent.item ?? "")")

        guard let itemName = intent.item, let home = intent.home else {
            return .failureInvalidItem(
                String(localized: "empty", comment: "empty item / home name")
            )
        }

        guard let homeId = home.uuid, await Preferences.shared.storedHomes[homeId] != nil else {
            return .failureInvalidItem(String(localized: "unknownHome", comment: "unknown home"))
        }

        guard let value = intent.value else {
            return .failureEmptyValue(item: itemName)
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: itemName, home: homeId), !items.isEmpty else {
            return .failureInvalidItem(itemName)
        }

        let item = items[0]

        await OpenHABItemCache.instance.sendCommand(to: item, home: homeId, command: value.stringValue)

        return .success(value: value, item: itemName)
    }
}
