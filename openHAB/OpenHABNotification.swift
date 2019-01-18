//
//  OpenHABNotification.swift
//  openHAB
//
//  Created by Victor Belov on 25/05/16.
//  Copyright © 2016 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18

import Foundation

extension OpenHABNotification {
    struct CodingData: Decodable {
            let _id : String
            let message : String
            let __v: Int
            let created: String
    }
}

extension OpenHABNotification.CodingData {
    var openHABNotification: OpenHABNotification {
        return OpenHABNotification(dictionary: ["message": self.message, "created": self.created ])
    }
}

class OpenHABNotification: NSObject {
    var message = ""
    var created: Date?
    var icon = ""
    var severity = ""
    let propertyNames: Set = ["message", "icon", "severity"]

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
//                if propertyNames.contains(key) {
//                    setValue(dictionary[key], forKey: key)
//                }
            }
        }
    }
    init (message: String) {
        self.message = message
    }
}
