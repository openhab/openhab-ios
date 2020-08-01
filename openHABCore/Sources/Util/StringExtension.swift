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
}

public enum WidgetType: String {
    case chart = "Chart"
    case colorpicker = "Colorpicker"
    case defaultWidget = "Default"
    case frame = "Frame"
    case group = "Group"
    case image = "Image"
    case mapview = "Mapview"
    case selection = "Selection"
    case setpoint = "Setpoint"
    case slider = "Slider"
    case switchWidget = "Switch"
    case text = "Text"
    case video = "Video"
    case webview = "Webview"
    case unknown = "Unknown"
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

        return ItemType(rawValue: typeString)
    }

    func toWidgetType() -> WidgetType? {
        WidgetType(rawValue: self)
    }
}
