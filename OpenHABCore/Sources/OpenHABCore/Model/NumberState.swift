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

public struct NumberState: CustomStringConvertible, Equatable {
    public var description: String {
        toString(locale: Locale.current)
    }

    public var value: Double
    private(set) var unit: String? = ""
    private(set) var format: String? = ""

    public var intValue: Int {
        Int(value)
    }

    public var stringValue: String {
        String(value)
    }

    // Access to default memberwise initializer not permitted outside of package
    public init(value: Double, unit: String? = "", format: String? = "") {
        self.value = value
        self.unit = unit
        self.format = format
    }

    public func toString(locale: Locale?) -> String {
        if let format, !format.isEmpty {
            let actualFormat = format
                .replacingOccurrences(of: "%unit%", with: unit ?? "")
                // %s in Java is for Strings, but does not work in Swift, see
                // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html)
                .replacingOccurrences(of: "%s", with: "%@")
            let formatValue: CVarArg = if format.contains("%d") {
                intValue
            } else if format.contains("%s") {
                stringValue
            } else {
                value
            }
            return String(format: actualFormat, locale: locale, formatValue)
        }
        if let unit, !unit.isEmpty {
            return "\(stringValue) \(unit)"
        } else {
            return stringValue
        }
    }

    private func getActualValue() -> NSNumber {
        if format?.contains("%d") == true {
            NSNumber(value: intValue)
        } else {
            NSNumber(value: value)
        }
    }
}
