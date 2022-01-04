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

class GetItemStateIntentHandler: NSObject, OpenHABGetItemStateIntentHandling {
    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: searchTerm, types: nil) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func provideItemOptionsCollection(for intent: OpenHABGetItemStateIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: nil, types: nil) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func confirm(intent: OpenHABGetItemStateIntent, completion: @escaping (OpenHABGetItemStateIntentResponse) -> Void) {
        completion(OpenHABGetItemStateIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABGetItemStateIntent, completion: @escaping (OpenHABGetItemStateIntentResponse) -> Void) {
        os_log("GetItemStateIntent for %{PUBLIC}@", log: .default, type: .info, intent.item ?? "")

        guard let itemName = intent.item else {
            completion(OpenHABGetItemStateIntentResponse.failureInvalidItem(NSLocalizedString("empty", comment: "empty item name")))
            return
        }

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item = item else {
                completion(OpenHABGetItemStateIntentResponse.failureInvalidItem(itemName))
                return
            }
            completion(OpenHABGetItemStateIntentResponse.success(item: itemName, state: item.state ?? NSLocalizedString("unknown", comment: "unknown item")))
        }
    }
}
