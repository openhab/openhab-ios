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
    // swiftlint:disable:next large_tuple
    private typealias PlaceholderResult = (argument: FormatArgument, finalSpecifier: Character, specifierIndex: String.Index, usesExplicitIndex: Bool)

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
        let valueString = if value.truncatingRemainder(dividingBy: 1) == 0,
                             value >= Double(Int.min),
                             value <= Double(Int.max) {
            String(Int(value))
        } else {
            String(value)
        }
        if let unit, !unit.isEmpty {
            return "\(valueString) \(unit)"
        }
        return valueString
    }

    private var fallbackString: String {
        if let unit, !unit.isEmpty {
            return "\(stringValue) \(unit)"
        }
        return stringValue
    }

    /// Access to default memberwise initializer not permitted outside of package
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

    private func parsePlaceholder(in format: String, from start: String.Index) -> PlaceholderResult? {
        var index = start

        while index < format.endIndex, "-+# 0".contains(format[index]) {
            index = format.index(after: index)
        }
        while index < format.endIndex, format[index].isNumber {
            index = format.index(after: index)
        }

        var usesExplicitIndex = false
        if index < format.endIndex, format[index] == "$" {
            guard format[start ..< index] == "1" else { return nil }
            usesExplicitIndex = true
            index = format.index(after: index)
            while index < format.endIndex, "-+# 0".contains(format[index]) {
                index = format.index(after: index)
            }
            while index < format.endIndex, format[index].isNumber {
                index = format.index(after: index)
            }
        }

        if index < format.endIndex, format[index] == "." {
            index = format.index(after: index)
            guard index < format.endIndex else { return nil }
            while index < format.endIndex, format[index].isNumber {
                index = format.index(after: index)
            }
        }

        if index < format.endIndex, "hlLqjzt".contains(format[index]) {
            let prev = format[index]
            index = format.index(after: index)
            if index < format.endIndex, (prev == "h" && format[index] == "h") || (prev == "l" && format[index] == "l") {
                index = format.index(after: index)
            }
        }

        guard index < format.endIndex else { return nil }
        let specifierIndex = index
        switch format[index] {
        case "@", "s": return (.string, "@", specifierIndex, usesExplicitIndex)
        case "d", "i", "u", "o", "x", "X": return (.int, format[index], specifierIndex, usesExplicitIndex)
        case "f", "F", "e", "E", "g", "G", "a", "A": return (.double, format[index], specifierIndex, usesExplicitIndex)
        default: return nil
        }
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
            if index == format.endIndex { return nil }
            if format[index] == "%" {
                normalized.append("%%")
                index = format.index(after: index)
                continue
            }
            guard let result = parsePlaceholder(in: format, from: index) else { return nil }
            if let firstArgument, firstArgument != result.argument { return nil }
            firstArgument = result.argument
            consumesArgumentCount += 1
            usesExplicitArgumentIndex = usesExplicitArgumentIndex || result.usesExplicitIndex
            normalized.append(contentsOf: format[percentIndex ..< result.specifierIndex])
            normalized.append(result.finalSpecifier)
            index = format.index(after: result.specifierIndex)
        }

        guard let firstArgument, consumesArgumentCount == 1 || usesExplicitArgumentIndex else { return nil }
        return (normalized, firstArgument)
    }
}
