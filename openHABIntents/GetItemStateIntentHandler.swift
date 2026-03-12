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

class GetItemStateIntentHandler: NSObject, OpenHABGetItemStateIntentHandling {
    func resolveHome(for intent: OpenHABGetItemStateIntent) async -> OpenHABHomeResolutionResult {
        Logger.intentHandling.info("Resolving home for intent: \(intent)")
        return await OpenHABIntentHelper.resolveHome(home: intent.home, item: intent.item)
    }

    func provideHomeOptionsCollection(for intent: OpenHABGetItemStateIntent) async throws -> INObjectCollection<OpenHABHome> {
        await OpenHABIntentHelper.getHomeOptions()
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, searchTerm: searchTerm)
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home)
    }

    func confirm(intent: OpenHABGetItemStateIntent) async -> OpenHABGetItemStateIntentResponse {
        OpenHABGetItemStateIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABGetItemStateIntent) async -> OpenHABGetItemStateIntentResponse {
        Logger.intentHandling.info("GetItemStateIntent for \(intent.item ?? "")")

        guard let itemName = intent.item, let home = intent.home else {
            return .failureInvalidItem(
                String(localized: "empty", comment: "empty item / home name")
            )
        }

        guard let homeId = home.uuid, await Preferences.shared.storedHomes[homeId] != nil else {
            return .failureInvalidItem(String(localized: "unknownHome", comment: "unknown home"))
        }

        let item = await OpenHABItemCache.instance.getItemUncached(name: itemName, home: homeId)

        guard let item else {
            return .failureInvalidItem(itemName)
        }

        return .success(
            item: itemName,
            state: item.state ?? String(localized: "unknownState", comment: "unknown item state")
        )
    }
}
