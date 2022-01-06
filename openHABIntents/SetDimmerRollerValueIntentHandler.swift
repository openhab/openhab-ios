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

class SetDimmerRollerValueIntentHandler: NSObject, OpenHABSetDimmerRollerValueIntentHandling {
    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: searchTerm, types: [OpenHABItem.ItemType.dimmer, OpenHABItem.ItemType.rollershutter]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        OpenHABItemCache.instance.getItemNames(searchTerm: nil, types: [OpenHABItem.ItemType.dimmer, OpenHABItem.ItemType.rollershutter]) { items in
            let retItems = INObjectCollection<NSString>(items: items)
            // Call the completion handler, passing the collection.
            completion(retItems, nil)
        }
    }

    func confirm(intent: OpenHABSetDimmerRollerValueIntent, completion: @escaping (OpenHABSetDimmerRollerValueIntentResponse) -> Void) {
        completion(OpenHABSetDimmerRollerValueIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABSetDimmerRollerValueIntent, completion: @escaping (OpenHABSetDimmerRollerValueIntentResponse) -> Void) {
        os_log("SetDimmerRollerValueIntent for %{PUBLIC}@", log: .default, type: .info, intent.item ?? "")

        guard let itemName = intent.item else {
            completion(OpenHABSetDimmerRollerValueIntentResponse.failureInvalidItem(NSLocalizedString("empty", comment: "empty item name")))
            return
        }

        guard let value = intent.value else {
            completion(OpenHABSetDimmerRollerValueIntentResponse.failureEmptyValue(item: itemName))
            return
        }

        let number = Int(truncating: value)

        if number < 0 || number > 100 {
            completion(OpenHABSetDimmerRollerValueIntentResponse.failureInvalidValue(value, item: itemName))
            return
        }

        OpenHABItemCache.instance.getItem(name: itemName) { item in
            guard let item = item else {
                completion(OpenHABSetDimmerRollerValueIntentResponse.failureInvalidItem(itemName))
                return
            }
            OpenHABItemCache.instance.sendCommand(item, commandToSend: "\(number)")

            completion(OpenHABSetDimmerRollerValueIntentResponse.success(value: NSNumber(value: number), item: itemName))
        }
    }
}
