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

class SetSwitchStateIntentHandler: NSObject, OpenHABSetSwitchStateIntentHandling {
    static let ON = NSLocalizedString("on", comment: "").capitalized // User language
    static let OFF = NSLocalizedString("off", comment: "").capitalized // User language
    static let ACTION_NAMES = [ON, OFF]
    static let ACTION_MAP = [ON: "ON", OFF: "OFF"] // these are the sent items - do not translate this text

    func provideActionOptionsCollection(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        let actions = INObjectCollection<NSString>(items: SetSwitchStateIntentHandler.ACTION_NAMES as [NSString])

        // Call the completion handler, passing the collection.
        completion(actions, nil)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: searchTerm, types: [OpenHABItem.ItemType.switchItem]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func provideItemOptionsCollection(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: nil, types: [OpenHABItem.ItemType.switchItem]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func confirm(intent: OpenHABSetSwitchStateIntent, completion: @escaping (OpenHABSetSwitchStateIntentResponse) -> Void) {
        completion(OpenHABSetSwitchStateIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABSetSwitchStateIntent, completion: @escaping (OpenHABSetSwitchStateIntentResponse) -> Void) {
        os_log("SetSwitchStateIntent for %{PUBLIC}@", log: .default, type: .info, intent.item ?? "")

        guard let itemName = intent.item else {
            completion(.failureInvalidItem(NSLocalizedString("empty", comment: "empty item name")))
            return
        }

        guard let action = intent.action else {
            completion(.failureInvalidAction(NSLocalizedString("empty", comment: "empty action"), item: itemName))
            return
        }

        // Map user language to real action
        guard let realAction = SetSwitchStateIntentHandler.ACTION_MAP[action] else {
            completion(.failureInvalidAction(action, item: itemName))
            return
        }

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item else {
                completion(.failureInvalidItem(itemName))
                return
            }
            OpenHABItemCache.instance.sendCommand(item, commandToSend: realAction)

            completion(.success(action: action, item: itemName))
        }
    }
}
