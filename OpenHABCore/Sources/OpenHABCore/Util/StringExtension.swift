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
import MapKit
import os.log
import UIKit

public extension String {
    internal var doubleValue: Double {
        if let value = try? Double(self, format: .number.locale(Locale(identifier: "en_US_POSIX"))) {
            value
        } else {
            Double.nan
        }
    }

    internal var intValue: Int {
        if let value = try? Int(self, format: .number.locale(Locale(identifier: "en_US_POSIX"))) {
            value
        } else {
            Int.max
        }
    }

    /**
     Transforms the string received in json response into NSNumber
     Independent of locale's decimal separator

     */
    internal var numberValue: NSNumber? {
        let filtered = filter("01234567890E.+-".contains)
        if let value = Double(filtered) {
            return NSNumber(value: value)
        }
        return nil
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

    /// Sub-view gape title optionally concatenated with one space and value if present - to be inline with Nsic UI
    /// e.g. "Living Room [21°C]" → "Living Room 21°C"
    var labelValueTitle: String {
        // Base text before the first “[”
        let base = components(separatedBy: "[")[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract first bracket content (without the brackets)
        let value: String? = {
            guard let match = self.firstMatch(of: /\[(.*?)\]/.dotMatchesNewlines()) else { return nil }
            return String(match.1)
        }()

        // Concatenate base + space + value (if present), else just base
        if let v = value, !v.isEmpty {
            return "\(base) \(v)"
        }
        return base
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

    internal func toWidgetType() -> OpenHABWidget.WidgetType {
        OpenHABWidget.WidgetType(rawValue: self) ?? .unknown
    }

    func parseAsBool() -> Bool {
        if self == "ON" { return true }
        // Try to parse as Float first
        if let floatValue = Float(self) {
            return floatValue > 0
        }
        if let brightness = parseAsBrightness() { return brightness != 0 }
        // Fallback
        return false
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
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }

    func parseAsBrightness() -> Int? {
        let values = components(separatedBy: ",")
        guard values.count == 3 else { return nil }
        return Int(values[2].asDouble.rounded())
    }

    func prepare() -> String {
        var input = replacing(/^\.\./, with: "")
        if !input.starts(with: "/") {
            input.insert("/", at: startIndex)
        }
        return input
    }

    func deletingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    func isValidURLByRegex() throws -> Bool {
        // Host alternatives:
        //   localhost
        //   IPv6 literal in brackets: [::1], [2001:db8::1], [fe80::1%25eth0], etc.
        //   IPv4: 192.168.1.1
        //   hostname: example.com, openhab.local
        let pattern = #"^(https?://)?(localhost|\[[^\]]+\]|(\d{1,3}\.){3}\d{1,3}|([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})(:\d+)?(/[^\s]*)?$"#

        let regex = try Regex(pattern).ignoresCase()

        return wholeMatch(of: regex) != nil
    }

    func testAsValidOpenHABURL() throws {
        var urlString = self

        guard try urlString.isValidURLByRegex() else {
            throw URLError(.badURL)
        }

        if !urlString.contains("://") {
            urlString = "http://" + urlString
        }

        guard let components = URLComponents(string: urlString) else {
            throw URLError(.badURL)
        }

        let allowedSchemes = ["http", "https"]
        if let scheme = components.scheme?.lowercased() {
            if !allowedSchemes.contains(scheme) {
                throw URLError(.unsupportedURL)
            }
        }

        guard let host = components.host, !host.isEmpty else {
            throw URLError(.badURL)
        }
    }

    func removeTrailingSlashes() -> String {
        replacing(/\/+$/, with: "")
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

    var isNilOrEmpty: Bool {
        self == nil || self!.isEmpty
    }
}

public extension String {
    var dataImageBase64Payload: String? {
        guard hasPrefix("data:image"),
              let separatorRange = range(of: ";base64,")
        else {
            return nil
        }
        return String(self[separatorRange.upperBound...])
    }

    var dataImageBase64Data: Data? {
        guard let payload = dataImageBase64Payload else {
            return nil
        }
        return Data(base64Encoded: payload)
    }

    var isNoneIcon: Bool {
        wholeMatch(of: /^(oh:([a-z]+:)?)?none$/) != nil
    }
}
