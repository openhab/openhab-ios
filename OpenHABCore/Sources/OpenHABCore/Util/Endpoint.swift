// Copyright (c) 2010-2026 Contributors to the openHAB project
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

    public var id: Self {
        self
    }

    public var description: String {
        switch self {
        case .png:
            String(localized: "PNG")
        case .svg:
            String(localized: "SVG")
        }
    }
}

public enum SortSitemapsOrder: Int, CaseIterable, CustomStringConvertible {
    case label
    case name

    public var description: String {
        switch self {
        case .label:
            String(localized: "Label")
        case .name:
            String(localized: "Name")
        }
    }
}

public extension SortSitemapsOrder {
    /// The field that leads when both are shown, matching the chosen sort order:
    /// sorting by name makes the name primary, sorting by label makes the label
    /// primary.
    func primaryText(for sitemap: OpenHABSitemap) -> String {
        self == .name ? sitemap.name : sitemap.label
    }

    /// The counterpart of `primaryText`.
    func secondaryText(for sitemap: OpenHABSitemap) -> String {
        self == .name ? sitemap.label : sitemap.name
    }

    /// Joins a primary and secondary display value into one line, collapsing to
    /// just the primary when both are equal (e.g. a sitemap whose name == label).
    static func combined(_ primary: String, _ secondary: String) -> String {
        primary == secondary ? primary : "\(primary) – \(secondary)"
    }
}

/// Which sitemap field(s) to show in menus and pickers. Independent of
/// `SortSitemapsOrder`, which only affects ordering and — for `.both` — which
/// field leads.
public enum SitemapNameLabelDisplayMode: Int, CaseIterable, Identifiable, CustomStringConvertible, Codable, Sendable {
    case name
    case label
    case both

    public var id: Self { self }

    public var description: String {
        switch self {
        case .name:
            String(localized: "Name")
        case .label:
            String(localized: "Label")
        case .both:
            String(localized: "Label and name")
        }
    }
}

public extension SitemapNameLabelDisplayMode {
    /// The value stored per home; `nil` (data saved before this setting existed)
    /// resolves to the default, `.label`, which matches the pre-setting behaviour
    /// so upgrading users keep seeing sitemap labels.
    static func resolved(_ stored: SitemapNameLabelDisplayMode?) -> SitemapNameLabelDisplayMode {
        stored ?? .label
    }

    /// Title (primary line) for a sitemap. In `.both`, `sortOrder` decides which
    /// field leads.
    func titleText(for sitemap: OpenHABSitemap, sortedBy sortOrder: SortSitemapsOrder) -> String {
        switch self {
        case .name:
            sitemap.name
        case .label:
            sitemap.label
        case .both:
            sortOrder.primaryText(for: sitemap)
        }
    }

    /// Detail (secondary line) for a sitemap: empty unless the mode is `.both`
    /// and the two fields actually differ.
    func detailText(for sitemap: OpenHABSitemap, sortedBy sortOrder: SortSitemapsOrder) -> String {
        guard self == .both else { return "" }
        let primary = sortOrder.primaryText(for: sitemap)
        let secondary = sortOrder.secondaryText(for: sitemap)
        return primary == secondary ? "" : secondary
    }

    /// Single-line form for pickers, e.g. `"Home – watch"` for `.both`.
    func combinedText(for sitemap: OpenHABSitemap, sortedBy sortOrder: SortSitemapsOrder) -> String {
        let title = titleText(for: sitemap, sortedBy: sortOrder)
        let detail = detailText(for: sitemap, sortedBy: sortOrder)
        return detail.isEmpty ? title : SortSitemapsOrder.combined(title, detail)
    }
}

public struct Endpoint: Equatable {
    let baseURL: String
    let path: String
    var queryItems: [URLQueryItem]
}

public extension Endpoint {
    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems
        return components?.url
//        Logger.endpoint.debug("URL: \(url?.absoluteString ?? "", privacy: .private)")
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
    static func chart(rootUrl: String, period: String?, type: OpenHABItem.ItemType?, service: String?, name: String?, legend: Bool?, theme: ChartStyle = .light, forceAsItem: Bool?, yAxisDecimalPattern: String? = nil) -> Endpoint {
        // Use a high-entropy cache buster to avoid stale chart snapshots caused by collisions.
        let random = UUID().uuidString
        var endpoint = Endpoint(
            baseURL: rootUrl,
            path: "/chart",
            queryItems: [
                URLQueryItem(name: "period", value: period),
                URLQueryItem(name: "random", value: random)
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
        if let yAxisDecimalPattern {
            endpoint.queryItems.append(URLQueryItem(name: "yAxisDecimalPattern", value: yAxisDecimalPattern))
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
    static func icon(rootUrl: String, version: Int, icon: String?, state: String?, iconType: IconType, iconColor: String, staticIcon: Bool? = nil, widgetId: String? = nil) -> Endpoint? {
        guard let icon, !icon.isEmpty else {
            return nil
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
                let colorString = uiColor.hexString
                if let colorString {
                    queryItems.append(URLQueryItem(name: "color", value: "#\(colorString)"))
                }
            }
            if let widgetId {
                queryItems.append(URLQueryItem(name: "widgetId", value: widgetId))
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

        // openHAB classic icon set does not provide a "number" icon; skip request entirely.
        if source == "oh", set == "classic", iconName == "number" {
            return nil
        }

        if staticIcon != true, let state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }

        queryItems.append(contentsOf: [
            URLQueryItem(name: "format", value: (iconType == .png) ? "PNG" : "SVG"),
            URLQueryItem(name: "anyFormat", value: "true"),
            URLQueryItem(name: "iconset", value: set)
        ])

        if let widgetId {
            queryItems.append(URLQueryItem(name: "widgetId", value: widgetId))
        }

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
