// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import UIKit

public enum ChartStyle {
    case dark
    case light
}

public enum IconType: Int, CaseIterable, Identifiable, CustomStringConvertible, Codable {
    case png
    case svg

    public var id: Self { self }

    public var description: String {
        switch self {
        case .png:
            "PNG"
        case .svg:
            "SVG"
        }
    }
}

public enum SortSitemapsOrder: Int, CaseIterable, CustomStringConvertible {
    case label
    case name

    public var description: String {
        switch self {
        case .label:
            "Label"
        case .name:
            "Name"
        }
    }
}

public struct Endpoint: Equatable {
    static let logger = Logger(subsystem: "org.openhab.app", category: "EndPoint")

    let baseURL: String
    let path: String
    var queryItems: [URLQueryItem]
}

extension UIColor {
    var rgbaDescription: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "r: %.2f, g: %.2f, b: %.2f, a: %.2f", r, g, b, a)
    }
}

public extension Endpoint {
    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems
        let url = components?.url
        Endpoint.logger.debug("URL: \(url?.absoluteString ?? "", privacy: .private)")
        return url
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
    static func icon(rootUrl: String, version: Int, icon: String?, state: String?, iconType: IconType, iconColor: String, staticIcon: Bool? = nil) -> Endpoint {
        guard let icon, !icon.isEmpty else {
            return Endpoint(baseURL: "", path: "", queryItems: [])
        }

        guard version >= 2 else {
            return Endpoint(
                baseURL: rootUrl,
                path: "/icon/\(icon)",
                queryItems: []
            )
        }

        // determineOH2IconPath
        var queryItems: [URLQueryItem] = []

        var source = "oh"
        var set = "classic"
        var iconName = "none"

        let segments = icon.components(separatedBy: ":")
        switch segments.count {
        case 1:
            iconName = segments[0]
        case 2:
            source = segments[0]
            iconName = segments[1]
            if source == "material" {
                set = "baseline"
            }
        case 3:
            source = segments[0]
            set = segments[1]
            iconName = segments[2]
        default:
            break
        }

        switch source {
        case "material":
            source = "iconify"
            iconName = iconName.replacingOccurrences(of: "_", with: "-")
            iconName = "\(set)-\(iconName)"
            set = "ic"
        case "f7":
            source = "iconify"
            set = "f7"
            iconName = iconName.replacingOccurrences(of: "_", with: "-")
        default:
            break
        }

        if source == "if" || source == "iconify" {
            queryItems = [URLQueryItem(name: "height", value: "64")]
            if !iconColor.isEmpty {
                let uiColor = UIColor(fromString: iconColor)
                logger.info("\(uiColor.rgbaDescription)")
                let colorString = uiColor.hexString
                logger.debug("color : \(colorString ?? "No proper color")")
                if let colorString {
                    queryItems.append(URLQueryItem(name: "color", value: "#\(colorString)"))
                }
            }
            return Endpoint(
                baseURL: "https://api.iconify.design/",
                path: "/\(set)/\(iconName).svg",
                queryItems: queryItems
            )
        }

        // set unknown iconSource to oh:classic:none icon
        if source != "oh" {
            set = "classic"
            iconName = "none"
        }

        if staticIcon != true {
            queryItems.append(URLQueryItem(name: "state", value: state ?? "null"))
        }

        queryItems.append(contentsOf: [
            URLQueryItem(name: "format", value: (iconType == .png) ? "PNG" : "SVG"),
            URLQueryItem(name: "anyFormat", value: "true"),
            URLQueryItem(name: "iconset", value: set)
        ])

        return Endpoint(
            baseURL: rootUrl,
            path: "/icon/\(iconName)",
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
