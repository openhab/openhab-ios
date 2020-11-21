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

class SetColorValueIntentHandler: NSObject, OpenHABSetColorValueIntentHandling {
    func provideItemOptionsCollection(for intent: OpenHABSetColorValueIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: searchTerm, types: [OpenHABItem.ItemType.color]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func provideItemOptionsCollection(for intent: OpenHABSetColorValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: nil, types: [OpenHABItem.ItemType.color]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func confirm(intent: OpenHABSetColorValueIntent, completion: @escaping (OpenHABSetColorValueIntentResponse) -> Void) {
        completion(OpenHABSetColorValueIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABSetColorValueIntent, completion: @escaping (OpenHABSetColorValueIntentResponse) -> Void) {
        os_log("SetColorValueIntent for %{PUBLIC}@", log: .default, type: .info, intent.item ?? "")

        guard let itemName = intent.item else {
            completion(OpenHABSetColorValueIntentResponse.failureInvalidItem("empty"))
            return
        }

        guard var value = intent.value else {
            completion(OpenHABSetColorValueIntentResponse.failureInvalidValue("empty", item: intent.item!))
            return
        }

        let hsb = value.split(separator: ",")
        if hsb.count != 3 {
            completion(OpenHABSetColorValueIntentResponse.failureInvalidValue(value, item: intent.item!))
            return
        }
        let hue = Int(hsb[0]) ?? 0
        let sat = Int(hsb[1]) ?? 0
        let val = Int(hsb[2]) ?? 0

        if hue < 0 || hue > 360 || sat < 0 || sat > 100 || val < 0 || val > 100 {
            completion(OpenHABSetColorValueIntentResponse.failureInvalidValue(value, item: intent.item!))
            return
        }
        value = "\(hue),\(sat),\(val)"

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item = item else {
                completion(OpenHABSetColorValueIntentResponse.failureInvalidItem(itemName))
                return
            }
            OpenHABItemCache.instance.sendCommand(item, commandToSend: value)

            completion(OpenHABSetColorValueIntentResponse.success(value: value, item: itemName))
        }
    }
}
