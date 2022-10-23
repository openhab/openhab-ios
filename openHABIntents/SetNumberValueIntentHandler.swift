// Copyright (c) 2010-2022 Contributors to the openHAB project
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
    func provideItemOptionsCollection(for intent: OpenHABSetNumberValueIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: searchTerm, types: [OpenHABItem.ItemType.number]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func provideItemOptionsCollection(for intent: OpenHABSetNumberValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: nil, types: [OpenHABItem.ItemType.number]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func confirm(intent: OpenHABSetNumberValueIntent, completion: @escaping (OpenHABSetNumberValueIntentResponse) -> Void) {
        completion(OpenHABSetNumberValueIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABSetNumberValueIntent, completion: @escaping (OpenHABSetNumberValueIntentResponse) -> Void) {
        os_log("SetNumberValueIntent for %{PUBLIC}@", log: .default, type: .info, intent.item ?? "")

        guard let itemName = intent.item else {
            completion(OpenHABSetNumberValueIntentResponse.failureInvalidItem(NSLocalizedString("empty", comment: "empty item name")))
            return
        }

        guard let value = intent.value else {
            completion(OpenHABSetNumberValueIntentResponse.failureEmptyValue(item: itemName))
            return
        }

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item else {
                completion(OpenHABSetNumberValueIntentResponse.failureInvalidItem(itemName))
                return
            }
            OpenHABItemCache.instance.sendCommand(item, commandToSend: value.stringValue)

            completion(OpenHABSetNumberValueIntentResponse.success(value: value, item: itemName))
        }
    }
}
