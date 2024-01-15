// Copyright (c) 2010-2024 Contributors to the openHAB project
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

    func provideStateOptionsCollection(for intent: OpenHABSetContactStateValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        let actions = INObjectCollection<NSString>(items: SetContactStateValueIntentHandler.ACTION_NAMES as [NSString])

        // Call the completion handler, passing the collection.
        completion(actions, nil)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetContactStateValueIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: searchTerm, types: [OpenHABItem.ItemType.contact]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func provideItemOptionsCollection(for intent: OpenHABSetContactStateValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: nil, types: [OpenHABItem.ItemType.contact]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func confirm(intent: OpenHABSetContactStateValueIntent, completion: @escaping (OpenHABSetContactStateValueIntentResponse) -> Void) {
        completion(OpenHABSetContactStateValueIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABSetContactStateValueIntent, completion: @escaping (OpenHABSetContactStateValueIntentResponse) -> Void) {
        os_log("SetContactStateValueIntent for %{PUBLIC}@", log: .default, type: .info, intent.item ?? "")

        guard let itemName = intent.item else {
            completion(OpenHABSetContactStateValueIntentResponse.failureInvalidItem(NSLocalizedString("empty", comment: "empty item name")))
            return
        }

        guard let state = intent.state else {
            completion(OpenHABSetContactStateValueIntentResponse.failureInvalidAction(state: NSLocalizedString("empty", comment: "empty value"), item: itemName))
            return
        }

        // Map user language to real action
        guard let realState = SetContactStateValueIntentHandler.ACTION_MAP[state] else {
            completion(OpenHABSetContactStateValueIntentResponse.failureInvalidAction(state: state, item: itemName))
            return
        }

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item else {
                completion(OpenHABSetContactStateValueIntentResponse.failureInvalidItem(itemName))
                return
            }
            OpenHABItemCache.instance.sendState(item, stateToSend: realState)

            completion(OpenHABSetContactStateValueIntentResponse.success(item: itemName, state: state))
        }
    }
}
