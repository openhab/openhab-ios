//
//  Endpoint.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 17.03.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import os.log

struct Endpoint {
    let baseURL: String
    let path: String
    var queryItems: [URLQueryItem]
}

extension Endpoint {

    static func watchSitemap(openHABRootUrl: String, sitemapName: String) -> Endpoint {
        return Endpoint(
            baseURL: openHABRootUrl,
            path: "/rest/sitemaps/" + sitemapName,
            queryItems: [
                URLQueryItem(name: "jsoncallback", value: "callback")
            ]
        )
    }

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

    static func tracker (openHABRootUrl: String) -> Endpoint {
        return Endpoint (
            baseURL: openHABRootUrl,
            path: "/rest/bindings",
            queryItems: []
        )
    }

    static func sitemaps (openHABRootUrl: String) -> Endpoint {
        return Endpoint (
            baseURL: openHABRootUrl,
            path: "/rest/sitemaps",
            queryItems: [
                URLQueryItem(name: "limit", value: "20")
            ]
        )
    }

    static func chart (rootUrl: String, period: String?, type: String?, service: String?, name: String?) -> Endpoint {

        let random = Int.random(in: 0..<1000)
        var endpoint = Endpoint (
            baseURL: rootUrl,
            path: "/chart",
            queryItems: [
                URLQueryItem(name: "period", value: period),
                URLQueryItem(name: "random", value: String(random))
            ]
        )
        if (type == "GroupItem") || (type == "Group") {
            endpoint.queryItems.append(URLQueryItem(name: "groups", value: name))
        } else {
            endpoint.queryItems.append(URLQueryItem(name: "items", value: name))
        }
        if service != "" && (service!.count) > 0 {
            endpoint.queryItems.append(URLQueryItem(name: "service", value: service))
        }
        return endpoint
    }

    static func icon (rootUrl: String, version: Int, icon: String?, value: String, iconType: Int) -> Endpoint {
        // determineOH2IconPath
        if version == 2 {
            if let icon = icon {
                return Endpoint(
                    baseURL: rootUrl,
                    path: "/icon/\(icon)",
                    queryItems: [
                        URLQueryItem(name: "state", value: value ),
                        URLQueryItem(name: "format", value: (iconType == 0) ? "PNG": "SVG")
                    ]
                )
            }
        } else {
            if let icon = icon {
                return Endpoint(
                    baseURL: rootUrl,
                    path: "/images/\(icon).png",
                    queryItems: []
                )
            }
        }
        return Endpoint(baseURL: "", path: "", queryItems: [])
    }

    static func iconForDrawer (rootUrl: String, version: Int, icon: String) -> Endpoint {

        if version == 2 {
            return Endpoint(
                baseURL: rootUrl,
                path: "/icon/\(icon).png",
                queryItems: []
            )
        } else {
            return Endpoint(
                baseURL: rootUrl,
                path: "/images/\(icon).png",
                queryItems: []
            )
        }
    }

    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems
        os_log("URL: %{PUBLIC}@", log: OSLog.urlComposition, type: .debug, components?.url?.absoluteString ?? "")
        return components?.url
    }

}
