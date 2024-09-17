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

public class OpenHABStateDescription {
    public var minimum = 0.0
    public var maximum = 100.0
    public var step = 1.0
    public var readOnly = false

    public var options: [OpenHABOptions] = []

    public var numberPattern: String?

    public init(minimum: Double?, maximum: Double?, step: Double?, readOnly: Bool?, options: [OpenHABOptions]?, pattern tobeSearched: String?) {
        self.minimum = minimum ?? 0.0
        self.maximum = maximum ?? 100.0
        self.step = step ?? 1.0
        self.readOnly = readOnly ?? false
        self.options = options ?? []

        // Remove transformation instructions (e.g. for 'MAP(foo.map):%s' keep only '%s')

        let regexPattern = /^[A-Z]+(\(.*\))?:(.*)$/.ignoresCase()
        if let tobeSearched {
            if let firstMatch = tobeSearched.firstMatch(of: regexPattern) {
                numberPattern = String(firstMatch.2)
            } else {
                numberPattern = tobeSearched
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

extension OpenHABStateDescription {
    convenience init?(_ state: Components.Schemas.StateDescription?) {
        if let state {
            self.init(minimum: state.minimum, maximum: state.maximum, step: state.step, readOnly: state.readOnly, options: state.options?.compactMap { OpenHABOptions($0) }, pattern: state.pattern)
        } else {
            return nil
        }
    }
}
