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

class SetContactStateValueIntentHandler: NSObject, OpenHABSetContactStateValueIntentHandling {
    func provideStateOptionsCollection(for intent: OpenHABSetContactStateValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        let actions = INObjectCollection<NSString>(items: ["OPEN", "CLOSED"])

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
            completion(OpenHABSetContactStateValueIntentResponse.failureInvalidItem("empty"))
            return
        }

        guard let state = intent.state else {
            completion(OpenHABSetContactStateValueIntentResponse.failureInvalidAction(state: "empty", item: itemName))
            return
        }

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item = item else {
                completion(OpenHABSetContactStateValueIntentResponse.failureInvalidItem(itemName))
                return
            }
            OpenHABItemCache.instance.sendState(item, stateToSend: state)

            completion(OpenHABSetContactStateValueIntentResponse.success(item: itemName, state: state))
        }
    }
}
