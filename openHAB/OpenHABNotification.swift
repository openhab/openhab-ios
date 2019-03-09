//
//  OpenHABNotification.swift
//  openHAB
//
//  Created by Victor Belov on 25/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18

import Foundation

// Custom DateFormatter to handle fractional seconds
// Inspired by https://useyourloaf.com/blog/swift-codable-with-custom-dates/
extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// We decode an instance of OpenHABNotification.CodingData rather than decoding a OpenHABNotificaiton value directly,
// We then convert that into a openHABNotification
// Inspired by https://www.swiftbysundell.com/basics/codable?rq=codingdata
extension OpenHABNotification {
    struct CodingData: Decodable {
        let id: String
        let message: String
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
        //return OpenHABNotification(dictionary: ["message": self.message, "created": self.created ])
        return OpenHABNotification(message: self.message, created: self.created)
    }

}

@objcMembers class OpenHABNotification: NSObject {
    var message = ""
    var created: Date?
    var icon = ""
    var severity = ""
    let propertyNames: Set = ["message", "icon", "severity"]

    init(message: String, created: Date?) {
        self.message = message
        self.created = created
    }

    init(dictionary: [String: Any]) {
        super.init()
        let keyArray = dictionary.keys
        for key in keyArray {
            if key as String == "created" {
                let dateFormatter = DateFormatter()
                // 2015-09-15T13:39:19.938Z
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.S'Z'"
                created = dateFormatter.date(from: dictionary[key] as? String ?? "")
            } else {
//                setValue("test", forKey: "message")
                if propertyNames.contains(key) {
                    setValue(dictionary[key], forKey: key)
                }
            }
        }
    }
    init (message: String) {
        self.message = message
    }
}
