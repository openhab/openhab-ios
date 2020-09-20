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
import os.log

public enum ChartStyle {
    case dark
    case light
}

public enum IconType: Int {
    case png
    case svg
}

public struct Endpoint {
    let baseURL: String
    let path: String
    var queryItems: [URLQueryItem]
}

extension Endpoint {
    public var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems
        os_log("URL: %{PUBLIC}@", log: OSLog.urlComposition, type: .debug, components?.url?.absoluteString ?? "")
        return components?.url
    }

    public static func watchSitemap(openHABRootUrl: String, sitemapName: String) -> Endpoint {
        Endpoint(baseURL: openHABRootUrl,
                 path: "/rest/sitemaps/\(sitemapName)/\(sitemapName)",
                 queryItems: [URLQueryItem(name: "jsoncallback", value: "callback")])
    }

    public static func appleRegistration(prefsURL: String,
                                         deviceToken: String,
                                         deviceId: String,
                                         deviceName: String) -> Endpoint {
        Endpoint(baseURL: prefsURL,
                 path: "/addAppleRegistration",
                 queryItems: [URLQueryItem(name: "regId", value: deviceToken),
                              URLQueryItem(name: "deviceId", value: deviceId),
                              URLQueryItem(name: "deviceModel", value: deviceName)])
    }

    public static func notification(prefsURL: String) -> Endpoint {
        Endpoint(baseURL: prefsURL,
                 path: "/api/v1/notifications",
                 queryItems: [URLQueryItem(name: "limit", value: "20")])
    }

    public static func tracker(openHABRootUrl: String) -> Endpoint {
        Endpoint(baseURL: openHABRootUrl,
                 path: "/rest/bindings",
                 queryItems: [])
    }

    public static func sitemaps(openHABRootUrl: String) -> Endpoint {
        Endpoint(baseURL: openHABRootUrl,
                 path: "/rest/sitemaps",
                 queryItems: [URLQueryItem(name: "limit", value: "20")])
    }

    public static func uiTiles(openHABRootUrl: String) -> Endpoint {
        Endpoint(baseURL: openHABRootUrl,
                 path: "/rest/ui/tiles",
                 queryItems: [])
    }

    public static func resource(openHABRootUrl: String, path: String) -> Endpoint {
        Endpoint(baseURL: openHABRootUrl,
                 path: path,
                 queryItems: [])
    }

    // swiftlint:disable:next function_parameter_count
    public static func chart(rootUrl: String, period: String?, type: String?, service: String?, name: String?, legend: Bool?, theme: ChartStyle = .light) -> Endpoint {
        let random = Int.random(in: 0 ..< 1000)
        var endpoint = Endpoint(baseURL: rootUrl,
                                path: "/chart",
                                queryItems: [URLQueryItem(name: "period", value: period),
                                             URLQueryItem(name: "random", value: String(random))])

        if let type = type, type.isAny(of: "GroupItem", "Group") {
            endpoint.queryItems.append(URLQueryItem(name: "groups", value: name))
        } else {
            endpoint.queryItems.append(URLQueryItem(name: "items", value: name))
        }
        if let service = service, !service.isEmpty {
            endpoint.queryItems.append(URLQueryItem(name: "service", value: service))
        }
        if let legend = legend {
            endpoint.queryItems.append(URLQueryItem(name: "legend", value: String(legend)))
        }
        switch theme {
        case .dark:
            endpoint.queryItems.append(URLQueryItem(name: "theme", value: "dark"))
        case .light:
            endpoint.queryItems.append(URLQueryItem(name: "theme", value: "light"))
        }
        return endpoint
    }

    public static func icon(rootUrl: String, version: Int, icon: String?, value: String, iconType: IconType) -> Endpoint {
        guard let icon = icon, !icon.isEmpty else {
            return Endpoint(baseURL: "", path: "", queryItems: [])
        }

        // determineOH2IconPath
        if version == 2 {
            return Endpoint(baseURL: rootUrl,
                            path: "/icon/\(icon)",
                            queryItems: [URLQueryItem(name: "state", value: value),
                                         URLQueryItem(name: "format", value: (iconType == .png) ? "PNG" : "SVG")])
        } else {
            return Endpoint(baseURL: rootUrl,
                            path: "/images/\(icon).png",
                            queryItems: [])
        }
    }

    public static func iconForDrawer(rootUrl: String, version: Int, icon: String) -> Endpoint {
        if version == 2 {
            return Endpoint(baseURL: rootUrl,
                            path: "/icon/\(icon).png",
                            queryItems: [])
        } else {
            return Endpoint(baseURL: rootUrl,
                            path: "/images/\(icon).png",
                            queryItems: [])
        }
    }
}

extension URL {
    public init(staticString string: StaticString) {
        guard let url = URL(string: "\(string)") else {
            preconditionFailure("Invalid static URL string: \(string)")
        }

        self = url
    }
}
