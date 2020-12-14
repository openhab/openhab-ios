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

public struct NumberState: CustomStringConvertible, Equatable {
    public var description: String {
        toString(locale: Locale.current)
    }

    public var value: Double
    private(set) var unit: String? = ""
    private(set) var format: String? = ""

    public func toString(locale: Locale?) -> String {
        if let format = format, format.isEmpty == false {
            let actualFormat = format.replacingOccurrences(of: "%unit%", with: unit ?? "")
            if format.contains("%d") == true {
                return String(format: actualFormat, locale: locale, Int(value))
            } else {
                return String(format: actualFormat, locale: locale, value)
            }
        }
        if let unit = unit, unit.isEmpty == false {
            return "\(formatValue()) \(unit)"
        } else {
            return formatValue()
        }
    }

    public func formatValue() -> String {
        String(value)
    }

    private func getActualValue() -> NSNumber {
        if format?.contains("%d") == true {
            return NSNumber(value: Int(value))
        } else {
            return NSNumber(value: value)
        }
    }
}
