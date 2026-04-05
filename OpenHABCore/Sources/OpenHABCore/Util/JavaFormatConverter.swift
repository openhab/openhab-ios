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

/// Converts Java `java.util.Formatter` printf-style format strings to rendered output
/// for openHAB Number item states.
///
/// Supports the subset of Java format syntax used by openHAB, plus Java-specific
/// features not available in Swift's `String(format:)`:
///
/// | Java feature | Handling |
/// |---|---|
/// | `%s` string specifier | mapped to `%@` |
/// | `%n` newline | → `\n` |
/// | `%b`/`%B` boolean | → `"true"`/`"false"` |
/// | `,` grouping-separator flag | via `NumberFormatter` |
/// | `(` negative-in-parentheses flag | via `NumberFormatter` |
/// | Positional indices `%1$…` / `%2$…` | arg 1 = value, arg 2 = unit |
///
/// The two implicit arguments are always:
/// - **arg 1** — the numeric `Double` value
/// - **arg 2** — the unit `String` (may be empty)
enum JavaFormatConverter {
    // MARK: - Public API

    /// Renders a Java-style format string with the given numeric value and optional unit.
    ///
    /// Returns `nil` if the format string is malformed, uses unsupported specifiers,
    /// addresses more than two arguments, or mixes incompatible argument types.
    static func render(javaFormat: String, value: Double, unit: String?, locale: Locale?) -> String? {
        var result = ""
        var index = javaFormat.startIndex
        var nextSequentialArg = 1 // 1-based, matches Java

        while index < javaFormat.endIndex {
            let ch = javaFormat[index]
            guard ch == "%" else {
                result.append(ch)
                index = javaFormat.index(after: index)
                continue
            }

            // Consume '%'
            index = javaFormat.index(after: index)
            guard index < javaFormat.endIndex else { return nil }

            // %% → literal %
            if javaFormat[index] == "%" {
                result.append("%")
                index = javaFormat.index(after: index)
                continue
            }

            // %n → platform newline (Java) → \n
            if javaFormat[index] == "n" {
                result.append("\n")
                index = javaFormat.index(after: index)
                continue
            }

            // --- Optional argument index: digits followed by '$' ---
            var argIndex: Int?
            var lookahead = index
            var digitStr = ""
            while lookahead < javaFormat.endIndex, javaFormat[lookahead].isNumber {
                digitStr.append(javaFormat[lookahead])
                lookahead = javaFormat.index(after: lookahead)
            }
            if !digitStr.isEmpty,
               lookahead < javaFormat.endIndex,
               javaFormat[lookahead] == "$" {
                guard let n = Int(digitStr), n >= 1, n <= 2 else { return nil }
                argIndex = n
                index = javaFormat.index(after: lookahead) // advance past '$'
            }
            // If no '$' found, 'index' is unchanged and 'digitStr' will be re-parsed as width below.

            // --- Flags ---
            var hasGrouping = false
            var hasParens = false
            var hasLeftAlign = false
            var hasPlus = false
            var hasSpace = false
            var hasZeroPad = false

            flagLoop: while index < javaFormat.endIndex {
                switch javaFormat[index] {
                case "-": hasLeftAlign = true
                case "+": hasPlus = true
                case " ": hasSpace = true
                case "0": hasZeroPad = true
                case ",": hasGrouping = true
                case "(": hasParens = true
                case "<": return nil // relative index — not supported
                default: break flagLoop
                }
                index = javaFormat.index(after: index)
            }

            // --- Width ---
            var widthStr = ""
            while index < javaFormat.endIndex, javaFormat[index].isNumber {
                widthStr.append(javaFormat[index])
                index = javaFormat.index(after: index)
            }
            let width = Int(widthStr)

            // --- Precision ---
            var precision: Int?
            if index < javaFormat.endIndex, javaFormat[index] == "." {
                index = javaFormat.index(after: index)
                var precStr = ""
                while index < javaFormat.endIndex, javaFormat[index].isNumber {
                    precStr.append(javaFormat[index])
                    index = javaFormat.index(after: index)
                }
                precision = Int(precStr) ?? 0
            }

            guard index < javaFormat.endIndex else { return nil }
            let conversion = javaFormat[index]
            index = javaFormat.index(after: index)

            // Resolve effective argument index
            let effectiveArgIndex: Int
            if let explicit = argIndex {
                effectiveArgIndex = explicit
            } else {
                effectiveArgIndex = nextSequentialArg
                nextSequentialArg += 1
            }

            // Swift String(format:) flags (subset safe for Swift)
            var swiftFlags = ""
            if hasLeftAlign { swiftFlags += "-" }
            if hasPlus { swiftFlags += "+" }
            if hasSpace { swiftFlags += " " }
            if hasZeroPad { swiftFlags += "0" }

            // Render this specifier
            let segment: String
            switch conversion {

            // Integer conversions — arg 1 only
            case "d", "x", "X", "o":
                guard effectiveArgIndex == 1 else { return nil }
                let intVal = Int(value)
                if hasGrouping || hasParens {
                    guard let s = renderInteger(intVal, width: width, flags: swiftFlags, grouping: hasGrouping, parens: hasParens, locale: locale) else { return nil }
                    segment = s
                } else {
                    var fmt = "%\(swiftFlags)"
                    if let w = width { fmt += "\(w)" }
                    fmt += String(conversion)
                    segment = String(format: fmt, locale: locale, intVal)
                }

            // Floating-point conversions — arg 1 only
            case "f", "F", "e", "E", "g", "G", "a", "A":
                guard effectiveArgIndex == 1 else { return nil }
                if hasGrouping || hasParens {
                    guard let s = renderFloat(value, conversion: conversion, width: width, precision: precision, flags: swiftFlags, grouping: hasGrouping, parens: hasParens, locale: locale) else { return nil }
                    segment = s
                } else {
                    var fmt = "%\(swiftFlags)"
                    if let w = width { fmt += "\(w)" }
                    if let p = precision { fmt += ".\(p)" }
                    fmt += String(conversion)
                    segment = String(format: fmt, locale: locale, value)
                }

            // String conversions — arg 1 = value as string, arg 2 = unit
            case "s", "S":
                let raw: String = effectiveArgIndex == 2
                    ? (unit ?? "")
                    : String(value)
                let strVal = conversion == "S" ? raw.uppercased() : raw
                if let w = width, strVal.count < w {
                    let padding = String(repeating: " ", count: w - strVal.count)
                    segment = hasLeftAlign ? strVal + padding : padding + strVal
                } else {
                    segment = strVal
                }

            // Boolean — non-zero = true; arg 1 only
            case "b":
                guard effectiveArgIndex == 1 else { return nil }
                segment = value != 0 ? "true" : "false"

            case "B":
                guard effectiveArgIndex == 1 else { return nil }
                segment = value != 0 ? "TRUE" : "FALSE"

            default:
                return nil
            }

            result.append(segment)
        }

        return result
    }

    // MARK: - NumberFormatter-backed rendering

    private static func renderInteger(
        _ value: Int,
        width: Int?,
        flags: String,
        grouping: Bool,
        parens: Bool,
        locale: Locale?
    ) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        if let locale { formatter.locale = locale }
        if parens, value < 0 {
            formatter.negativeFormat = "(#,##0)"
        }
        guard var s = formatter.string(from: NSNumber(value: value)) else { return nil }
        if let w = width { s = pad(s, width: w, leftAlign: flags.contains("-")) }
        return s
    }

    private static func renderFloat(
        _ value: Double,
        conversion: Character,
        width: Int?,
        precision: Int?,
        flags: String,
        grouping: Bool,
        parens: Bool,
        locale: Locale?
    ) -> String? {
        let prec = precision ?? 6
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.minimumFractionDigits = prec
        formatter.maximumFractionDigits = prec
        if let locale { formatter.locale = locale }
        if parens, value < 0 {
            let zeros = String(repeating: "0", count: prec)
            formatter.negativeFormat = prec > 0 ? "(#,##0.\(zeros))" : "(#,##0)"
        }
        guard var s = formatter.string(from: NSNumber(value: value)) else { return nil }
        if let w = width { s = pad(s, width: w, leftAlign: flags.contains("-")) }
        return s
    }

    // MARK: - Padding

    private static func pad(_ s: String, width: Int, leftAlign: Bool) -> String {
        guard s.count < width else { return s }
        let padding = String(repeating: " ", count: width - s.count)
        return leftAlign ? s + padding : padding + s
    }
}
