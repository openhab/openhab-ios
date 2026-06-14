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

public enum WidgetMediaKind: String, Sendable {
    case chart
    case image
    case other
}

public enum WidgetMediaItemPayloadSnapshot: Sendable, Equatable {
    case link(String)
    case embedded(Data)
    case empty
}

public struct WidgetMediaImageDescriptor: Sendable, Equatable {
    public let mediaKind: WidgetMediaKind
    public let url: String
    public let period: String
    public let service: String
    public let itemTypeRawValue: String?
    public let itemName: String?
    public let legend: Bool?
    public let forceAsItem: Bool?
    public let yAxisDecimalPattern: String?
    public let itemPayload: WidgetMediaItemPayloadSnapshot

    public init(mediaKind: WidgetMediaKind,
                url: String,
                period: String,
                service: String,
                itemTypeRawValue: String?,
                itemName: String?,
                legend: Bool?,
                forceAsItem: Bool?,
                yAxisDecimalPattern: String?,
                itemPayload: WidgetMediaItemPayloadSnapshot) {
        self.mediaKind = mediaKind
        self.url = url
        self.period = period
        self.service = service
        self.itemTypeRawValue = itemTypeRawValue
        self.itemName = itemName
        self.legend = legend
        self.forceAsItem = forceAsItem
        self.yAxisDecimalPattern = yAxisDecimalPattern
        self.itemPayload = itemPayload
    }

    public func resolveImagePayload(rootUrl: String,
                                    chartStyle: ChartStyle = .light) -> ImagePayload {
        switch mediaKind {
        case .chart:
            let itemType = itemTypeRawValue.flatMap(OpenHABItem.ItemType.init(rawValue:))
            guard let chartURL = Endpoint.chart(
                rootUrl: rootUrl,
                period: period,
                type: itemType,
                service: service,
                name: itemName,
                legend: legend,
                theme: chartStyle,
                forceAsItem: forceAsItem,
                yAxisDecimalPattern: yAxisDecimalPattern
            ).url else {
                Logger.restAPI.error("Failed to generate chart URL")
                return .empty
            }
            return .link(url: chartURL)

        case .image:
            switch itemPayload {
            case let .embedded(data):
                return .embedded(data: data)
            case let .link(link):
                return .link(url: resolveURL(link, against: rootUrl))
            case .empty:
                guard let imageURL = resolveURL(url, against: rootUrl) else {
                    Logger.restAPI.error("Invalid image URL: \(url)")
                    return .empty
                }
                return .link(url: imageURL)
            }

        case .other:
            return .empty
        }
    }
}

public extension OpenHABWidget {
    var mediaImageDescriptor: WidgetMediaImageDescriptor {
        let itemPayload: WidgetMediaItemPayloadSnapshot = if let item {
            switch item.getImagePayload() {
            case let .embedded(data):
                .embedded(data)
            case let .link(url):
                .link(url?.absoluteString ?? "")
            case .empty:
                .empty
            }
        } else {
            .empty
        }

        return WidgetMediaImageDescriptor(
            mediaKind: type.mediaKind,
            url: url,
            period: period,
            service: service,
            itemTypeRawValue: item?.type?.rawValue,
            itemName: item?.name,
            legend: legend,
            forceAsItem: forceAsItem,
            yAxisDecimalPattern: yAxisDecimalPattern,
            itemPayload: itemPayload
        )
    }
}

private func resolveURL(_ urlString: String, against rootUrl: String) -> URL? {
    guard !urlString.isEmpty else { return nil }
    let base = URL(string: rootUrl)
    guard let resolved = URL(string: urlString, relativeTo: base)?.absoluteURL,
          resolved.scheme != nil else { return nil }
    return resolved
}

private extension OpenHABWidget.WidgetType {
    var mediaKind: WidgetMediaKind {
        switch self {
        case .chart:
            .chart
        case .image:
            .image
        default:
            .other
        }
    }
}
