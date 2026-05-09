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
    private enum FormatArgument {
        case int
        case double
        case string
    }

    public var description: String {
        toString(locale: Locale.current)
    }

    public var value: Double
    public private(set) var unit: String? = ""
    public private(set) var format: String? = ""

    public var intValue: Int {
        Int(value)
    }

    public var stringValue: String {
        String(value)
    }

    /// Value string suitable for sending as a command to the server.
    /// Sends integers without decimal suffix (36 not 36.0) so HTTP binding
    /// string substitution (%2$s) passes clean values to downstream devices.
    /// Fractional values are preserved (30.3 is never truncated to 30).
    public var commandString: String {
        let valueString: String
        if value.truncatingRemainder(dividingBy: 1) == 0,
           value >= Double(Int.min),
           value <= Double(Int.max) {
            valueString = String(Int(value))
        } else {
            valueString = String(value)
        }
        if let unit, !unit.isEmpty {
            return "\(valueString) \(unit)"
        }
        return valueString
    }

    // Access to default memberwise initializer not permitted outside of package
    public init(value: Double, unit: String? = "", format: String? = "") {
        self.value = value
        self.unit = unit
        self.format = format
    }

    public func toString(locale: Locale?) -> String {
        if let format, !format.isEmpty {
            var actualFormat = format
                .replacingOccurrences(of: "%unit%", with: unit ?? "")

            // Escape trailing % that isn't already escaped (e.g., "%.0f %" should become "%.0f %%")
            // This handles server-side format patterns that forgot to escape the percent sign
            if actualFormat.hasSuffix(" %"), !actualFormat.hasSuffix(" %%") {
                actualFormat = String(actualFormat.dropLast()) + "%%"
            }

            guard let normalized = normalizedFormat(actualFormat) else {
                return fallbackString
            }

            switch normalized.argument {
            case .int:
                return String(format: normalized.format, locale: locale, intValue)
            case .double:
                return String(format: normalized.format, locale: locale, value)
            case .string:
                return String(format: normalized.format, locale: locale, stringValue)
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

    private func normalizedFormat(_ format: String) -> (format: String, argument: FormatArgument)? {
        var normalized = ""
        var index = format.startIndex
        var firstArgument: FormatArgument?
        var consumesArgumentCount = 0
        var usesExplicitArgumentIndex = false

        while index < format.endIndex {
            let character = format[index]
            if character != "%" {
                normalized.append(character)
                index = format.index(after: index)
                continue
            }

            let percentIndex = index
            index = format.index(after: index)

            if index == format.endIndex {
                return nil
            }

            if format[index] == "%" {
                normalized.append("%%")
                index = format.index(after: index)
                continue
            }

            let placeholderStart = index

            while index < format.endIndex, "-+# 0".contains(format[index]) {
                index = format.index(after: index)
            }

            while index < format.endIndex, format[index].isNumber {
                index = format.index(after: index)
            }

            if index < format.endIndex, format[index] == "$" {
                let digits = format[placeholderStart ..< index]
                guard digits == "1" else { return nil }
                usesExplicitArgumentIndex = true
                index = format.index(after: index)
            }

            while index < format.endIndex, "-+# 0".contains(format[index]) {
                index = format.index(after: index)
            }

            while index < format.endIndex, format[index].isNumber {
                index = format.index(after: index)
            }

            if index < format.endIndex, format[index] == "." {
                index = format.index(after: index)
                guard index < format.endIndex else { return nil }
                while index < format.endIndex, format[index].isNumber {
                    index = format.index(after: index)
                }
            }

            if index < format.endIndex, "hlLqjzt".contains(format[index]) {
                index = format.index(after: index)
                if index < format.endIndex,
                   (format[format.index(before: index)] == "h" && format[index] == "h") ||
                    (format[format.index(before: index)] == "l" && format[index] == "l") {
                    index = format.index(after: index)
                }
            }

            guard index < format.endIndex else { return nil }

            let specifier = format[index]
            let argument: FormatArgument
            let finalSpecifier: Character
            switch specifier {
            case "@", "s":
                argument = .string
                finalSpecifier = "@"
            case "d", "i", "u", "o", "x", "X":
                argument = .int
                finalSpecifier = specifier
            case "f", "F", "e", "E", "g", "G", "a", "A":
                argument = .double
                finalSpecifier = specifier
            default:
                return nil
            }

            if let firstArgument, firstArgument != argument {
                return nil
            }
            firstArgument = argument
            consumesArgumentCount += 1

            normalized.append(contentsOf: format[percentIndex ..< index])
            normalized.append(finalSpecifier)
            index = format.index(after: index)
        }

        guard let firstArgument else {
            return nil
        }
        guard consumesArgumentCount == 1 || usesExplicitArgumentIndex else {
            return nil
        }

        return (normalized, firstArgument)
    }
}
