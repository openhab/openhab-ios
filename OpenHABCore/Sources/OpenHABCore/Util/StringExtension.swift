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
import MapKit
import os.log
import UIKit

public extension String {
    internal var doubleValue: Double {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."
        if let asNumber = formatter.number(from: self) {
            return asNumber.doubleValue
        } else {
            return Double.nan
        }
    }

    internal var intValue: Int {
        if let asNumber = NumberFormatter().number(from: self) {
            asNumber.intValue
        } else {
            Int.max
        }
    }

    /**
     Transforms the string received in json response into NSNumber
     Independent of locale's decimal separator

     */
    internal var numberValue: NSNumber? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .scientific
        formatter.decimalSeparator = "."
        return formatter.number(from: filter("01234567890E.+-".contains))
    }

    internal var asDouble: Double {
        numberValue?.doubleValue ?? 0
    }

    var isValidURL: Bool {
        // return nil if the URL has not a valid format
        URL(string: self) != nil
    }

    var isAbsoluteURL: Bool {
        URL(string: self) == URL(string: self)?.absoluteURL
    }

    internal func toItemType() -> OpenHABItem.ItemType? {
        var typeString: String = self
        // Earlier OH2 versions returned e.g. 'Switch' as 'SwitchItem'
        if hasSuffix("Item") {
            typeString = String(dropLast(4))
        }
        // types can have subtypes (e.g. 'Number:Temperature'); split off those
        let firstColon = firstIndex(of: ":")
        if let firstColon {
            typeString = String(typeString[..<firstColon])
        }

        if typeString == "Number", firstColon != nil {
            return .numberWithDimension
        }

        return OpenHABItem.ItemType(rawValue: typeString)
    }

    internal func toWidgetType() -> OpenHABWidget.WidgetType? {
        OpenHABWidget.WidgetType(rawValue: self)
    }

    func parseAsBool() -> Bool {
        if self == "ON" { return true }
        if let brightness = parseAsBrightness() { return brightness != 0 }
        if let decimalValue = Int(self) {
            return decimalValue > 0
        } else {
            return false
        }
    }

    func parseAsNumber(format: String? = nil) -> NumberState {
        switch self {
        case "ON": return NumberState(value: 100.0)
        case "OFF": return NumberState(value: 0.0)
        default:
            let components = split(separator: " ").map { String($0) }
            let number = String(components[safe: 0] ?? "")
            let unit = components[safe: 1]
            return NumberState(value: number.asDouble, unit: unit, format: format)
        }
    }

    func parseAsUIColor() -> UIColor? {
        guard self != "Uninitialized" else {
            return .black
        }
        let values = components(separatedBy: ",")
        guard values.count == 3 else { return nil }
        let hue = CGFloat(state: values[0], divisor: 360)
        let saturation = CGFloat(state: values[1], divisor: 100)
        let brightness = CGFloat(state: values[2], divisor: 100)
        os_log("hue saturation brightness: %g %g %g", log: .default, type: .info, hue, saturation, brightness)
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }

    func parseAsBrightness() -> Int? {
        let values = components(separatedBy: ",")
        guard values.count == 3 else { return nil }
        return Int(values[2].asDouble.rounded())
    }

    func prepare() -> String {
        var input = replacingOccurrences(of: "^\\.\\.", with: "", options: [.regularExpression])
        if !input.starts(with: "/") {
            input.insert("/", at: startIndex)
        }
        return input
    }

    func deletingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}

public extension String? {
    var orEmpty: String {
        switch self {
        case let .some(value):
            value
        case .none:
            ""
        }
    }
}
