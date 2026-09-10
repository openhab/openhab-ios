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

public struct OpenHABSitemapWidgetEvent: Sendable {
    public let sitemapName: String?
    public let pageId: String?
    public let widgetId: String?
    public let label: String?
    public let labelSource: String?
    public let icon: String?
    public let reloadIcon: Bool?
    public let labelcolor: String?
    public let valuecolor: String?
    public let iconcolor: String?
    public let commandConfirmMessage: String?
    public let visibility: Bool?
    public let state: String?
    public let enrichedItem: OpenHABItem?
    public let descriptionChanged: Bool?

    public init(sitemapName: String? = nil,
                pageId: String? = nil,
                widgetId: String? = nil,
                label: String? = nil,
                labelSource: String? = nil,
                icon: String? = nil,
                reloadIcon: Bool? = nil,
                labelcolor: String? = nil,
                valuecolor: String? = nil,
                iconcolor: String? = nil,
                commandConfirmMessage: String? = nil,
                visibility: Bool? = nil,
                state: String? = nil,
                enrichedItem: OpenHABItem? = nil,
                descriptionChanged: Bool? = nil) {
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
        self.commandConfirmMessage = commandConfirmMessage
        self.visibility = visibility
        self.state = state
        self.enrichedItem = enrichedItem
        self.descriptionChanged = descriptionChanged
    }

    public init?(_ event: Components.Schemas.SitemapWidgetEvent?) {
        guard let event else { return nil }
        self.init(
            sitemapName: event.sitemapName,
            pageId: event.pageId,
            widgetId: event.widgetId,
            label: event.label,
            labelSource: event.labelSource,
            icon: event.icon,
            reloadIcon: event.reloadIcon,
            labelcolor: event.labelcolor,
            valuecolor: event.valuecolor,
            iconcolor: event.iconcolor,
            commandConfirmMessage: event.commandConfirmMessage,
            visibility: event.visibility,
            state: event.state,
            enrichedItem: OpenHABItem(event.item),
            descriptionChanged: event.descriptionChanged
        )
    }
}

extension OpenHABSitemapWidgetEvent: CustomStringConvertible {
    public var description: String {
        "\(widgetId ?? "") \(label ?? "") \(enrichedItem?.state ?? "")"
    }
}
