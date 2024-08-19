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

import CoreLocation
import os.log
import UIKit

public class OpenHABItem: NSObject, CommItem {
    public enum ItemType: String {
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
        case undetermind = "" // Relevant only for SitemapWidgetEvent
    }

    public var type: ItemType?
    public var groupType: ItemType?
    public var name = ""
    public var state: String?
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

    public init(name: String, type: String, state: String?, link: String, label: String?, groupType: String?, stateDescription: OpenHABStateDescription?, commandDescription: OpenHABCommandDescription?, members: [OpenHABItem], category: String?, options: [OpenHABOptions]?) {
        self.name = name
        self.type = type.toItemType()
        if let state, state == "NULL" || state == "UNDEF" || state.caseInsensitiveCompare("undefined") == .orderedSame {
            self.state = nil
        } else {
            self.state = state
        }
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
                os_log("hue saturation brightness: %g %g %g", log: .default, type: .info, hue, saturation, brightness)
                return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
            } else {
                return .black
            }
        } else {
            return .black
        }
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
}

public extension OpenHABItem {
    struct CodingData: Decodable {
        let type: String?
        let groupType: String?
        let name: String
        let link: String?
        let state: String?
        let label: String?
        let stateDescription: OpenHABStateDescription.CodingData?
        let commandDescription: OpenHABCommandDescription.CodingData?
        let members: [OpenHABItem.CodingData]?
        let category: String?
        let options: [OpenHABOptions]?
    }
}

// swiftlint:disable line_length
public extension OpenHABItem.CodingData {
    var openHABItem: OpenHABItem {
        let mappedMembers = members?.map(\.openHABItem) ?? []

        return OpenHABItem(name: name, type: type ?? "", state: state, link: link ?? "", label: label, groupType: groupType, stateDescription: stateDescription?.openHABStateDescription, commandDescription: commandDescription?.openHABCommandDescription, members: mappedMembers, category: category, options: options)
    }
}

// swiftlint:enable line_length

extension CGFloat {
    init(state string: String, divisor: Float) {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "US")
        if let number = numberFormatter.number(from: string) {
            self.init(number.floatValue / divisor)
        } else {
            self.init(0)
        }
    }
}
