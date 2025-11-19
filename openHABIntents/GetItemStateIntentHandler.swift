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
    func resolveHome(for intent: OpenHABGetItemStateIntent) async -> OpenHABHomeResolutionResult {
        Logger.intentHandling.info("Resolving home for intent: \(intent)")
        return await OpenHABIntentHelper.resolveHome(home: intent.home, item: intent.item)
    }

    func provideHomeOptionsCollection(for intent: OpenHABGetItemStateIntent) async throws -> INObjectCollection<OpenHABHome> {
        await OpenHABIntentHelper.getHomeOptions()
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        Logger.intentHandling.info("provideItemOptionsCollection called with home: \(intent.home?.identifier ?? "nil"), searchTerm: \(searchTerm ?? "nil")")
        return await OpenHABIntentHelper.getItemOptions(home: intent.home, searchTerm: searchTerm)
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent) async throws -> INObjectCollection<NSString> {
        Logger.intentHandling.info("provideItemOptionsCollection called with home: \(intent.home?.identifier ?? "nil")")
        return await OpenHABIntentHelper.getItemOptions(home: intent.home)
    }

    func confirm(intent: OpenHABGetItemStateIntent) async -> OpenHABGetItemStateIntentResponse {
        OpenHABGetItemStateIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABGetItemStateIntent) async -> OpenHABGetItemStateIntentResponse {
        Logger.intentHandling.info("GetItemStateIntent for \(intent.item ?? "")")

        guard let itemName = intent.item, let home = intent.home else {
            return .failureInvalidItem(
                NSLocalizedString("empty", comment: "empty item / home name")
            )
        }

        guard let homeId = home.uuid else {
            return .failureInvalidItem(NSLocalizedString("unknownHome", comment: "unknown home"))
        }

        // Apply fallback if home doesn't exist
        let storedHomes = await Preferences.shared.storedHomes
        let actualHomeId: UUID
        if storedHomes[homeId] != nil {
            actualHomeId = homeId
        } else {
            Logger.intentHandling.warning("Home \(homeId) not found in handle. Falling back to first available home")
            guard let firstHome = storedHomes.first else {
                return .failureInvalidItem(NSLocalizedString("unknownHome", comment: "unknown home"))
            }
            actualHomeId = firstHome.key
        }

        let item = await OpenHABItemCache.instance.getItemUncached(name: itemName, home: actualHomeId)

        guard let item else {
            return .failureInvalidItem(itemName)
        }

        return .success(
            item: itemName,
            state: item.state ?? NSLocalizedString("unknownState", comment: "unknown item state")
        )
    }
}
