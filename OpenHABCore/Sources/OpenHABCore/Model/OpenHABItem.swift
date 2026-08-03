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

import CoreLocation
import os.log
import UIKit

public struct OpenHABItem: Sendable {
    public enum ItemType: String, Sendable {
        case color = "Color"
        case contact = "Contact"
        case dateTime = "DateTime"
        case dimmer = "Dimmer"
        case group = "Group"
        case image = "Image"
        case location = "Location"
        case number = "Number"
        case numberWithDimension = "NumberWithDimension"
        case player = "Player"
        case rollershutter = "Rollershutter"
        case stringItem = "String"
        case switchItem = "Switch"
        case undetermined = "" // Relevant only for SitemapWidgetEvent
    }

    public var type: ItemType?
    public var groupType: ItemType?
    public var name = ""
    public var state: String?
    public var transformedState: String?
    public var link = ""
    public var label = ""
    public var stateDescription: OpenHABStateDescription?
    public var commandDescription: OpenHABCommandDescription?
    public var readOnly = false
    public var members: [OpenHABItem] = []
    public var category = ""
    public var options: [OpenHABOptions] = []

    var canBeToggled: Bool {
        isOfTypeOrGroupType(ItemType.color) ||
            isOfTypeOrGroupType(ItemType.contact) ||
            isOfTypeOrGroupType(ItemType.dimmer) ||
            isOfTypeOrGroupType(ItemType.rollershutter) ||
            isOfTypeOrGroupType(ItemType.switchItem) ||
            isOfTypeOrGroupType(ItemType.player)
    }

    public init(name: String, type: String, state: String?, link: String, label: String?, groupType: String?, stateDescription: OpenHABStateDescription?, commandDescription: OpenHABCommandDescription?, members: [OpenHABItem], category: String?, options: [OpenHABOptions]?, transformedState: String? = nil) {
        self.name = name
        self.type = type.toItemType()
        if let state, state == "NULL" || state == "UNDEF" || state.caseInsensitiveCompare("undefined") == .orderedSame {
            self.state = nil
        } else {
            self.state = state
        }
        self.transformedState = transformedState.flatMap { $0.isEmpty ? nil : $0 }
        self.link = link
        self.label = label.orEmpty
        self.groupType = groupType?.toItemType()
        self.stateDescription = stateDescription
        self.commandDescription = commandDescription
        readOnly = stateDescription?.readOnly ?? false
        self.members = members
        self.category = category.orEmpty
        self.options = options ?? []
    }

    public func isOfTypeOrGroupType(_ type: ItemType) -> Bool {
        self.type == type || groupType == type
    }
}

extension OpenHABItem.ItemType: Decodable {}

public extension OpenHABItem {
    func stateAsDouble() -> Double {
        state?.numberValue?.doubleValue ?? 0
    }

    func stateAsInt() -> Int {
        state?.numberValue?.intValue ?? 0
    }

    func stateAsUIColor() -> UIColor {
        if let state {
            let values = state.components(separatedBy: ",")
            if values.count == 3 {
                let hue = CGFloat(state: values[0], divisor: 360)
                let saturation = CGFloat(state: values[1], divisor: 100)
                let brightness = CGFloat(state: values[2], divisor: 100)
                Logger.restAPI.info("hue saturation brightness: \(hue) \(saturation) \(brightness)")
                return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
            }
            return .black
        }
        return .black
    }

    func stateAsLocation() -> CLLocation? {
        if type == .location {
            // Example of `state` string for location: '0.000000,0.000000,0.0' ('<latitude>,<longitude>,<altitude>')
            if let state {
                let locationComponents = state.components(separatedBy: ",")
                if locationComponents.count >= 2 {
                    let latitude = CLLocationDegrees(Double(locationComponents[0]) ?? 0.0)
                    let longitude = CLLocationDegrees(Double(locationComponents[1]) ?? 0.0)

                    return CLLocation(latitude: latitude, longitude: longitude)
                }
            } else {
                return nil
            }
        }
        return nil
    }

    func getImagePayload() -> ImagePayload {
        switch type {
        case .image:
            guard let data = state?.components(separatedBy: ",")[safe: 1], let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters) else {
                return .empty
            }
            return .embedded(data: decodedData)
        case .stringItem:
            return .link(url: URL(string: state ?? ""))
        default:
            return .empty
        }
    }
}

extension OpenHABItem {
    init?(_ item: Components.Schemas.EnrichedItemDTO?) {
        // unitSymbol
        // tags
        if let item {
            self.init(
                name: item.name.orEmpty,
                type: item._type.orEmpty,
                state: item.state.orEmpty,
                link: item.link.orEmpty,
                label: item.label.orEmpty,
                groupType: item.groupType,
                stateDescription: OpenHABStateDescription(item.stateDescription),
                commandDescription: OpenHABCommandDescription(item.commandDescription),
                members: [],
                category: item.category,
                options: [],
                transformedState: item.transformedState
            )
        } else {
            return nil
        }
    }
}
