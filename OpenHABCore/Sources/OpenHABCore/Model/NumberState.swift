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

    /// Value string suitable for sending as a command to the server.
    /// Preserves full numeric precision (never truncated by display format)
    /// and appends the unit when present.
    public var commandString: String {
        if let unit, !unit.isEmpty {
            return "\(stringValue) \(unit)"
        }
        return stringValue
    }

    // Access to default memberwise initializer not permitted outside of package
    public init(value: Double, unit: String? = "", format: String? = "") {
        self.value = value
        self.unit = unit
        self.format = format
    }

    public func toString(locale: Locale?) -> String {
        if let format, !format.isEmpty {
            var javaFormat = format.replacingOccurrences(of: "%unit%", with: unit ?? "")

            // Escape a bare trailing % the server forgot to escape (e.g. "%.0f %")
            if javaFormat.hasSuffix(" %"), !javaFormat.hasSuffix(" %%") {
                javaFormat = String(javaFormat.dropLast()) + "%%"
            }

            if let rendered = JavaFormatConverter.render(javaFormat: javaFormat, value: value, unit: unit, locale: locale) {
                return rendered
            }
        }
        return fallbackString
    }

    private var fallbackString: String {
        if let unit, !unit.isEmpty {
            return "\(stringValue) \(unit)"
        }
        return stringValue
    }
}
