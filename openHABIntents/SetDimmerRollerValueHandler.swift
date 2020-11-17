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

class SetDimmerRollerValueIntentHandler: NSObject, OpenHABSetDimmerRollerValueIntentHandling {
    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent, searchTerm: String?, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        let items = OpenHABItemCache.instance.getItemNames(searchTerm: searchTerm, types: ["Dimmer", "Rollershutter"])

        let retItems = INObjectCollection<NSString>(items: items)

        // Call the completion handler, passing the collection.
        completion(retItems, nil)
    }

    func provideItemOptionsCollection(for intent: OpenHABSetDimmerRollerValueIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        let items = OpenHABItemCache.instance.getItemNames(searchTerm: nil, types: ["Dimmer", "Rollershutter"])

        let retItems = INObjectCollection<NSString>(items: items)

        // Call the completion handler, passing the collection.
        completion(retItems, nil)
    }

    func defaultItem(for intent: OpenHABSetDimmerRollerValueIntent) -> String? {
        if OpenHABItemCache.instance.items == nil {
            OpenHABItemCache.instance.reload()
            return ""
        }

        return ""
    }

    func confirm(intent: OpenHABSetDimmerRollerValueIntent, completion: @escaping (OpenHABSetDimmerRollerValueIntentResponse) -> Void) {
        completion(OpenHABSetDimmerRollerValueIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: OpenHABSetDimmerRollerValueIntent, completion: @escaping (OpenHABSetDimmerRollerValueIntentResponse) -> Void) {
        os_log("SetDimmerRollerValueIntent for %{PUBLIC}@", log: .default, type: .info, intent.item ?? "")

        guard let item = OpenHABItemCache.instance.getItem(intent.item ?? "") else {
            completion(OpenHABSetDimmerRollerValueIntentResponse.failureInvalidItem(intent.item!))
            return
        }

        guard intent.value != nil else {
            completion(OpenHABSetDimmerRollerValueIntentResponse.failureInvalidValue(item: intent.item!))
            return
        }

        let value = intent.value!.stringValue
        OpenHABItemCache.instance.sendCommand(item, commandToSend: value)

        completion(OpenHABSetDimmerRollerValueIntentResponse.success(item: item.name, value: intent.value!))
    }
}
