// Copyright (c) 2010-2022 Contributors to the openHAB project
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

public class OpenHABStateDescription {
    public var minimum = 0.0
    public var maximum = 100.0
    public var step = 1.0
    public var readOnly = false

    public var options: [OpenHABOptions] = []

    public var numberPattern: String?

    init(minimum: Double?, maximum: Double?, step: Double?, readOnly: Bool?, options: [OpenHABOptions]?, pattern: String?) {
        self.minimum = minimum ?? 0.0
        self.maximum = maximum ?? 100.0
        self.step = step ?? 1.0
        self.readOnly = readOnly ?? false
        self.options = options ?? []

        // Remove transformation instructions (e.g. for 'MAP(foo.map):%s' keep only '%s')

        let regexPattern = #"^[A-Z]+(\(.*\))?:(.*)$"#
        let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive)
        if let pattern = pattern {
            let nsrange = NSRange(pattern.startIndex ..< pattern.endIndex, in: pattern)
            if let match = regex?.firstMatch(in: pattern, options: [], range: nsrange) {
                if let range = Range(match.range(at: 2), in: pattern) {
                    numberPattern = String(pattern[range])
                }
            } else {
                numberPattern = pattern
            }
        } else {
            numberPattern = nil
        }
    }
}

public extension OpenHABStateDescription {
    struct CodingData: Decodable {
        let minimum: Double?
        let maximum: Double?
        let step: Double?
        let readOnly: Bool?
        let options: [OpenHABOptions]?
        let pattern: String?
    }
}

extension OpenHABStateDescription.CodingData {
    var openHABStateDescription: OpenHABStateDescription {
        OpenHABStateDescription(minimum: minimum, maximum: maximum, step: step, readOnly: readOnly, options: options, pattern: pattern)
    }
}
