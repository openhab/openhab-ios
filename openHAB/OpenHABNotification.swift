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

class OpenHABNotification: NSObject {
    var message: String?
    var created: Date?
    var icon: String?
    var severity: String?
    var id = ""
    init(message: String? = nil, created: Date? = nil, icon: String? = nil, severity: String? = nil, id: String = "") {
        self.message = message
        self.created = created
        self.icon = icon
        self.severity = severity
        self.id = id
    }

    convenience init(dictionary: [String: Any]) {
        let propertyNames: Set = ["message", "icon", "severity"]
        self.init()
        let keyArray = dictionary.keys
        for key in keyArray {
            if key as String == "created" {
                let dateFormatter = DateFormatter()
                // 2015-09-15T13:39:19.938Z
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.S'Z'"
                created = dateFormatter.date(from: dictionary[key] as? String ?? "")
            } else {
                if propertyNames.contains(key) {
                    setValue(dictionary[key], forKey: key)
                }
            }
        }
    }
}

// Decode an instance of OpenHABNotification.CodingData rather than decoding a OpenHABNotificaiton value directly,
// then convert that into a openHABNotification
// Inspired by https://www.swiftbysundell.com/basics/codable?rq=codingdata
extension OpenHABNotification {
    public struct CodingData: Decodable {
        let id: String
        let message: String?
        let v: Int
        let created: Date?

        private enum CodingKeys: String, CodingKey {
            case id = "_id"
            case message
            case v = "__v"
            case created
        }
    }
}

// Convenience method to convert a decoded value into a proper OpenHABNotification instance
extension OpenHABNotification.CodingData {
    var openHABNotification: OpenHABNotification {
        OpenHABNotification(message: message, created: created, id: id)
    }
}
