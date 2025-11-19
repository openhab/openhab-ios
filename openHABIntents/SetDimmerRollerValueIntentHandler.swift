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

class SetDimmerRollerValueIntentHandler: NSObject, OpenHABSetDimmerRollerValueIntentHandling {
    func resolveHome(for intent: OpenHABSetDimmerRollerValueIntent) async -> OpenHABHomeResolutionResult {
        Logger.intentHandling.info("Resolving home for intent: \(intent)")
        return await OpenHABIntentHelper.resolveHome(home: intent.home, item: intent.item)
    }

    func provideHomeOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent) async throws -> INObjectCollection<OpenHABHome> {
        await OpenHABIntentHelper.getHomeOptions()
    }

    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, searchTerm: searchTerm, itemTypes: [.dimmer, .rollershutter])
    }

    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent) async throws -> INObjectCollection<NSString> {
        await OpenHABIntentHelper.getItemOptions(home: intent.home, itemTypes: [.dimmer, .rollershutter])
    }

    func confirm(intent: OpenHABSetDimmerRollerValueIntent) async -> OpenHABSetDimmerRollerValueIntentResponse {
        OpenHABSetDimmerRollerValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetDimmerRollerValueIntent) async -> OpenHABSetDimmerRollerValueIntentResponse {
        Logger.intentHandling.info("SetDimmerRollerValueIntent for \(intent.item ?? "")")

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

        guard let value = intent.value else {
            return .failureEmptyValue(item: itemName)
        }

        let number = Int(truncating: value)

        guard (0 ... 100).contains(number) else {
            return .failureInvalidValue(value, item: itemName)
        }

        guard let items = await OpenHABItemCache.instance.getCachedItem(name: itemName, home: actualHomeId), !items.isEmpty else {
            return .failureInvalidItem(itemName)
        }

        let item = items[0]

        await OpenHABItemCache.instance.sendCommand(to: item, home: actualHomeId, command: "\(number)")

        return .success(value: NSNumber(value: number), item: itemName)
    }
}
