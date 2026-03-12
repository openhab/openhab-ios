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

class SetColorValueIntentHandler: NSObject, OpenHABSetColorValueIntentHandling {
    func resolveHome(for intent: OpenHABSetColorValueIntent) async -> OpenHABHomeResolutionResult {
        Logger.intentHandling.info("Resolving home for intent: \(intent)")
        return await OpenHABIntentHelper.resolveHome(home: intent.home, item: intent.item)
    }

    func provideHomeOptionsCollection(for intent: OpenHABSetColorValueIntent) async throws -> INObjectCollection<OpenHABHome> {
        await OpenHABIntentHelper.getHomeOptions()
    }

    func provideItemOptionsCollection(for intent: OpenHABSetColorValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, searchTerm: searchTerm, itemTypes: [.color])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetColorValueIntent) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, itemTypes: [.color])
    }

    func confirm(intent: OpenHABSetColorValueIntent) async -> OpenHABSetColorValueIntentResponse {
        OpenHABSetColorValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetColorValueIntent) async -> OpenHABSetColorValueIntentResponse {
        Logger.intentHandling.info("SetColorValueIntent for \(intent.item ?? "")")

        guard let itemName = intent.item, let home = intent.home else {
            return .failureInvalidItem(
                String(localized: "empty", comment: "empty item / home name")
            )
        }

        guard let homeId = home.uuid, await Preferences.shared.storedHomes[homeId] != nil else {
            return .failureInvalidItem(String(localized: "unknownHome", comment: "unknown home"))
        }

        guard var value = intent.value else {
            return .failureInvalidValue(
                String(localized: "empty", comment: "empty value"),
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

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: itemName, home: homeId), !items.isEmpty else {
            return .failureInvalidItem(itemName)
        }

        let item = items[0]

        await OpenHABItemCache.instance.sendCommand(to: item, home: homeId, command: value)

        return .success(value: value, item: itemName)
    }
}
