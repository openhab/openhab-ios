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

public enum ItemType {
    case color
    case contact
    case dateTime
    case dimmer
    case group
    case image
    case location
    case number
    case numberWithDimension
    case player
    case rollershutter
    case stringItem
    case switchItem
}

public enum WidgetType {
    case chart
    case colorpicker
    case defaultWidget
    case frame
    case group
    case image
    case mapview
    case selection
    case setpoint
    case slider
    case switchWidget
    case text
    case video
    case webview
    case unknown
}

extension String {
    var doubleValue: Double {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."
        if let asNumber = formatter.number(from: self) {
            return asNumber.doubleValue
        } else {
            return Double.nan
        }
    }

    var intValue: Int {
        if let asNumber = NumberFormatter().number(from: self) {
            return asNumber.intValue
        } else {
            return Int.max
        }
    }

    /**
     Transforms the string received in json response into NSNumber
     Independent of locale's decimal separator

     */
    var numberValue: NSNumber? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = "."
        return formatter.number(from: filter("01234567890.-".contains))
    }

    func toItemType() -> ItemType? {
        var typeString: String = self
        // Earlier OH2 versions returned e.g. 'Switch' as 'SwitchItem'
        if hasSuffix("Item") {
            typeString = String(dropLast(4))
        }
        // types can have subtypes (e.g. 'Number:Temperature'); split off those
        let firstColon = firstIndex(of: ":")
        if let firstColon = firstColon {
            typeString = String(typeString[..<firstColon])
        }

        if typeString == "Number", firstColon != nil {
            return .numberWithDimension
        }
        switch typeString {
        case "Color": return .color
        case "Contact": return .contact
        case "DateTime": return .dateTime
        case "Dimmer": return .dimmer
        case "Group": return .group
        case "Image": return .image
        case "Location": return .location
        case "Number": return .number
        case "Player": return .player
        case "Rollershutter": return .rollershutter
        case "Switch": return .switchItem
        case "String": return .stringItem
        default: return nil
        }
    }

    func toWidgetType() -> WidgetType? {
        switch self {
        case "Chart": return .chart
        case "Colorpicker": return .colorpicker
        case "Default": return .defaultWidget
        case "Frame": return .frame
        case "Group": return .group
        case "Image": return .image
        case "Mapview": return .mapview
        case "Selection": return .selection
        case "Setpoint": return .setpoint
        case "Slider": return .slider
        case "Switch": return .switchWidget
        case "Text": return .text
        case "Video": return .video
        case "Webview": return .webview
        case "Unknown": return .unknown
        default: return .unknown
        }
    }
}
