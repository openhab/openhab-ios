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
    static let OPEN = NSLocalizedString("open", comment: "").capitalized // User language
    static let CLOSED = NSLocalizedString("closed", comment: "").capitalized // User language
    static let ACTION_NAMES = [OPEN, CLOSED]
    static let ACTION_MAP = [OPEN: "OPEN", CLOSED: "CLOSED"] // these are the sent items - do not translate this text

    private let logger = Logger(subsystem: "org.openhab.app", category: "SetColorValueIntent")

    func provideStateOptionsCollection(for intent: OpenHABSetContactStateValueIntent) async throws -> INObjectCollection<NSString> {
        INObjectCollection(items: Self.ACTION_NAMES.map(NSString.init))
    }

    func provideItemOptionsCollection(for intent: OpenHABSetContactStateValueIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        let items = await OpenHABItemCache.instance
            .getItemNames(searchTerm: searchTerm, types: [.contact])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetContactStateValueIntent) async throws -> INObjectCollection<NSString> {
        let items = await OpenHABItemCache.instance
            .getItemNames(searchTerm: nil, types: [.contact])
            .map(NSString.init)
        return INObjectCollection(items: items)
    }

    func confirm(intent: OpenHABSetContactStateValueIntent) async -> OpenHABSetContactStateValueIntentResponse {
        OpenHABSetContactStateValueIntentResponse(code: .ready, userActivity: nil)
    }

    func handle(intent: OpenHABSetContactStateValueIntent) async -> OpenHABSetContactStateValueIntentResponse {
        logger.info("SetContactStateValueIntent for \(intent.item ?? "")")

        guard let itemName = intent.item else {
            return .failureInvalidItem(NSLocalizedString("empty", comment: "empty item name"))
        }

        guard let state = intent.state else {
            return .failureInvalidAction(
                state: NSLocalizedString("empty", comment: "empty value"),
                item: itemName
            )
        }

        guard let realState = Self.ACTION_MAP[state] else {
            return .failureInvalidAction(state: state, item: itemName)
        }

        guard let item = await OpenHABItemCache.instance.getItem(name: itemName) else {
            return .failureInvalidItem(itemName)
        }

        await OpenHABItemCache.instance.sendState(item, stateToSend: realState)

        return .success(item: itemName, state: state)
    }
}
