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

public class OpenHABSitemapWidgetEvent {
    var sitemapName: String?
    var pageId: String?
    var widgetId: String?
    var label: String?
    var labelSource: String?
    var icon: String?
    var reloadIcon: Bool?
    var labelcolor: String?
    var valuecolor: String?
    var iconcolor: String?
    var visibility: Bool?
    var state: String?
    var enrichedItem: OpenHABItem?
    var descriptionChanged: Bool?

    init(sitemapName: String? = nil, pageId: String? = nil, widgetId: String? = nil, label: String? = nil, labelSource: String? = nil, icon: String? = nil, reloadIcon: Bool? = nil, labelcolor: String? = nil, valuecolor: String? = nil, iconcolor: String? = nil, visibility: Bool? = nil, state: String? = nil, enrichedItem: OpenHABItem? = nil, descriptionChanged: Bool? = nil) {
        self.sitemapName = sitemapName
        self.pageId = pageId
        self.widgetId = widgetId
        self.label = label
        self.labelSource = labelSource
        self.icon = icon
        self.reloadIcon = reloadIcon
        self.labelcolor = labelcolor
        self.valuecolor = valuecolor
        self.iconcolor = iconcolor
        self.visibility = visibility
        self.state = state
        self.enrichedItem = enrichedItem
        self.descriptionChanged = descriptionChanged
    }

    convenience init?(_ event: Components.Schemas.SitemapWidgetEvent?) {
        guard let event else { return nil }
        // swiftlint:disable:next line_length
        self.init(sitemapName: event.sitemapName, pageId: event.pageId, widgetId: event.widgetId, label: event.label, labelSource: event.labelSource, icon: event.icon, reloadIcon: event.reloadIcon, labelcolor: event.labelcolor, valuecolor: event.valuecolor, iconcolor: event.iconcolor, visibility: event.visibility, state: event.state, enrichedItem: OpenHABItem(event.item), descriptionChanged: event.descriptionChanged)
    }
}

extension OpenHABSitemapWidgetEvent: CustomStringConvertible {
    public var description: String {
        "\(widgetId ?? "") \(label ?? "") \(enrichedItem?.state ?? "")"
    }
}

public extension OpenHABSitemapWidgetEvent {
    struct CodingData: Decodable, Hashable, Equatable {
        public static func == (lhs: OpenHABSitemapWidgetEvent.CodingData, rhs: OpenHABSitemapWidgetEvent.CodingData) -> Bool {
            lhs.widgetId == rhs.widgetId
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(widgetId)
        }

        var sitemapName: String?
        var pageId: String?
        var widgetId: String?
        var label: String?
        var labelSource: String?
        var icon: String?
        var reloadIcon: Bool?
        var labelcolor: String?
        var valuecolor: String?
        var iconcolor: String?
        var visibility: Bool?
//        var state: String?
        var item: OpenHABItem.CodingData?
        var descriptionChanged: Bool?
        var link: String?
    }
}

extension OpenHABSitemapWidgetEvent.CodingData {
    var openHABSitemapWidgetEvent: OpenHABSitemapWidgetEvent {
        // swiftlint:disable:next line_length
        OpenHABSitemapWidgetEvent(sitemapName: sitemapName, pageId: pageId, widgetId: widgetId, label: label, labelSource: labelSource, icon: icon, reloadIcon: reloadIcon, labelcolor: labelcolor, valuecolor: valuecolor, iconcolor: iconcolor, visibility: visibility, enrichedItem: item?.openHABItem, descriptionChanged: descriptionChanged)
    }
}
