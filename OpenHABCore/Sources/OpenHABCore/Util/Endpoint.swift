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
import os.log

public enum ChartStyle {
    case dark
    case light
}

public enum IconType: Int {
    case png
    case svg
}

public enum SortSitemapsOrder: Int {
    case label
    case name
}

public struct Endpoint {
    let baseURL: String
    let path: String
    var queryItems: [URLQueryItem]
}

public extension Endpoint {
    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems
        os_log("URL: %{PUBLIC}@", log: OSLog.urlComposition, type: .debug, components?.url?.absoluteString ?? "")
        return components?.url
    }

    static func watchSitemap(openHABRootUrl: String, sitemapName: String) -> Endpoint {
        Endpoint(
            baseURL: openHABRootUrl,
            path: "/rest/sitemaps/\(sitemapName)/\(sitemapName)",
            queryItems: [URLQueryItem(name: "jsoncallback", value: "callback")]
        )
    }

    static func appleRegistration(prefsURL: String,
                                  deviceToken: String,
                                  deviceId: String,
                                  deviceName: String) -> Endpoint {
        Endpoint(
            baseURL: prefsURL,
            path: "/addIosRegistration",
            queryItems: [
                URLQueryItem(name: "regId", value: deviceToken),
                URLQueryItem(name: "deviceId", value: deviceId),
                URLQueryItem(name: "deviceModel", value: deviceName)
            ]
        )
    }

    static func notification(prefsURL: String) -> Endpoint {
        Endpoint(
            baseURL: prefsURL,
            path: "/api/v1/notifications",
            queryItems: [URLQueryItem(name: "limit", value: "20")]
        )
    }

    static func tracker(openHABRootUrl: String) -> Endpoint {
        Endpoint(
            baseURL: openHABRootUrl,
            path: "/rest/",
            queryItems: []
        )
    }

    static func sitemaps(openHABRootUrl: String) -> Endpoint {
        Endpoint(
            baseURL: openHABRootUrl,
            path: "/rest/sitemaps",
            queryItems: [URLQueryItem(name: "limit", value: "20")]
        )
    }

    static func items(openHABRootUrl: String) -> Endpoint {
        Endpoint(
            baseURL: openHABRootUrl,
            path: "/rest/items",
            queryItems: []
        )
    }

    static func uiTiles(openHABRootUrl: String) -> Endpoint {
        Endpoint(
            baseURL: openHABRootUrl,
            path: "/rest/ui/tiles",
            queryItems: []
        )
    }

    static func resource(openHABRootUrl: String, path: String) -> Endpoint {
        Endpoint(
            baseURL: openHABRootUrl,
            path: path,
            queryItems: []
        )
    }

    // swiftlint:disable:next function_parameter_count
    static func chart(rootUrl: String, period: String?, type: OpenHABItem.ItemType?, service: String?, name: String?, legend: Bool?, theme: ChartStyle = .light, forceAsItem: Bool?) -> Endpoint {
        let random = Int.random(in: 0 ..< 1000)
        var endpoint = Endpoint(
            baseURL: rootUrl,
            path: "/chart",
            queryItems: [
                URLQueryItem(name: "period", value: period),
                URLQueryItem(name: "random", value: String(random))
            ]
        )

        let forceAsItem = forceAsItem ?? false

        if type == .group, !forceAsItem {
            endpoint.queryItems.append(URLQueryItem(name: "groups", value: name))
        } else {
            endpoint.queryItems.append(URLQueryItem(name: "items", value: name))
        }
        if let service, !service.isEmpty {
            endpoint.queryItems.append(URLQueryItem(name: "service", value: service))
        }
        if let legend {
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

    // swiftlint:disable:next function_parameter_count
    static func icon(rootUrl: String, version: Int, icon: String?, state: String, iconType: IconType, iconColor: String) -> Endpoint {
        guard var icon, !icon.isEmpty else {
            return Endpoint(baseURL: "", path: "", queryItems: [])
        }

        // determineOH2IconPath
        var queryItems = [
            URLQueryItem(name: "state", value: state)
        ]
        if version >= 4 {
            let components = icon.components(separatedBy: ":")
            var source = ""
            var set = ""
            if components.count == 3 {
                source = components[0]
                set = components[1]
                icon = components[2]
            } else if components.count == 2 {
                source = components[0]
                if source == "material" {
                    set = "baseline"
                } else {
                    set = "classic"
                }
                icon = components[1]
            }
            if source == "material" {
                source = "iconify"
                icon = icon.replacingOccurrences(of: "_", with: "-")
                icon = "\(set)-\(icon)"
                set = "ic"
            }
            if source == "f7" {
                source = "iconify"
                set = "f7"
                icon = icon.replacingOccurrences(of: "_", with: "-")
            }
            if source == "if" || source == "iconify" {
                queryItems = [URLQueryItem(name: "height", value: "64")]
                if !iconColor.isEmpty {
                    queryItems.append(URLQueryItem(name: "color", value: iconColor))
                }
                return Endpoint(
                    baseURL: "https://api.iconify.design/",
                    path: "/\(set)/\(icon).svg",
                    queryItems: queryItems
                )
            }
        }
        if version >= 3 {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "format", value: (iconType == .png) ? "PNG" : "SVG"),
                URLQueryItem(name: "anyFormat", value: "true")
            ])
        } else {
            queryItems.append(
                URLQueryItem(name: "format", value: (iconType == .png) ? "PNG" : "SVG")
            )
        }

        return Endpoint(
            baseURL: rootUrl,
            path: "/icon/\(icon)",
            queryItems: queryItems
        )
    }

    static func iconForDrawer(rootUrl: String, icon: String) -> Endpoint {
        Endpoint(
            baseURL: rootUrl,
            path: "/icon/\(icon).png",
            queryItems: []
        )
    }
}

public extension URL {
    init(staticString string: StaticString) {
        guard let url = URL(string: "\(string)") else {
            preconditionFailure("Invalid static URL string: \(string)")
        }

        self = url
    }
}
