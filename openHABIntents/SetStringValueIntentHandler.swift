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

class SetStringValueIntentHandler: NSObject, OpenHABSetStringValueIntentHandling {
    func provideItemOptionsCollection(for intent: OpenHABSetStringValueIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: searchTerm, types: [OpenHABItem.ItemType.stringItem]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func provideItemOptionsCollection(for intent: OpenHABSetStringValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: nil, types: [OpenHABItem.ItemType.stringItem]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func confirm(intent: OpenHABSetStringValueIntent, completion: @escaping (OpenHABSetStringValueIntentResponse) -> Void) {
        completion(OpenHABSetStringValueIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABSetStringValueIntent, completion: @escaping (OpenHABSetStringValueIntentResponse) -> Void) {
        os_log("SetStringValueIntent for %{public}@", log: .default, type: .info, intent.item ?? "")

        guard let itemName = intent.item else {
            completion(OpenHABSetStringValueIntentResponse.failureInvalidItem(NSLocalizedString("empty", comment: "empty item name")))
            return
        }

        guard let value = intent.value else {
            completion(OpenHABSetStringValueIntentResponse.failureEmptyValue(item: itemName))
            return
        }

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item else {
                completion(OpenHABSetStringValueIntentResponse.failureInvalidItem(itemName))
                return
            }
            OpenHABItemCache.instance.sendCommand(item, commandToSend: value)

            completion(OpenHABSetStringValueIntentResponse.success(value: value, item: itemName))
        }
    }
}
