// Copyright (c) 2010-2020 Contributors to the openHAB project
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
    func provideActionOptionsCollection(for intent: OpenHABSetSwitchStateIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        let actions = INObjectCollection<NSString>(items: ["ON", "OFF"])

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
            completion(OpenHABSetSwitchStateIntentResponse.failureInvalidItem("empty"))
            return
        }

        guard let action = intent.action else {
            completion(OpenHABSetSwitchStateIntentResponse.failureInvalidAction("empty", item: itemName))
            return
        }

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item = item else {
                completion(OpenHABSetSwitchStateIntentResponse.failureInvalidItem(itemName))
                return
            }
            OpenHABItemCache.instance.sendCommand(item, commandToSend: action)

            completion(OpenHABSetSwitchStateIntentResponse.success(action: action, item: itemName))
        }
    }
}
