//
//  Endpoint.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 17.03.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

struct Endpoint {
    let baseURL: String
    let path: String
    let queryItems: [URLQueryItem]
}

extension Endpoint {
    static func appleRegistration (prefsURL: String,
                                   deviceToken: String,
                                   deviceId: String,
                                   deviceName: String) -> Endpoint {
        return Endpoint (
            baseURL: prefsURL,
            path: "/addAppleRegistration",
            queryItems: [
                URLQueryItem(name: "regId", value: deviceToken),
                URLQueryItem(name: "deviceId", value: deviceId),
                URLQueryItem(name: "deviceModel", value: deviceName)
            ]
        )
    }

    static func notification (prefsURL: String) -> Endpoint {
        return Endpoint (
            baseURL: prefsURL,
            path: "/api/v1/notifications",
            queryItems: [
                URLQueryItem(name: "limit", value: "20")
            ]
        )
    }

    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems
        return components?.url
    }

}
