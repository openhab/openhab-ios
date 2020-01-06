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

public class OpenHABStateDescription {
    public var minimum = 0.0
    public var maximum = 100.0
    public var step = 1.0
    public var readOnly = false

    public var options: [OpenHABOptions] = []

    init(minimum: Double?, maximum: Double?, step: Double?, readOnly: Bool?, options: [OpenHABOptions]?) {
        self.minimum = minimum ?? 0.0
        self.maximum = maximum ?? 100.0
        self.step = step ?? 1.0
        self.readOnly = readOnly ?? false
        self.options = options ?? []
    }
}

extension OpenHABStateDescription {
    public struct CodingData: Decodable {
        let minimum: Double?
        let maximum: Double?
        let step: Double?
        let readOnly: Bool?
        let options: [OpenHABOptions]?
    }
}

extension OpenHABStateDescription.CodingData {
    var openHABStateDescription: OpenHABStateDescription {
        return OpenHABStateDescription(minimum: minimum, maximum: maximum, step: step, readOnly: readOnly, options: options)
    }
}
