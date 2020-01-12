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
import Fuzi

class OpenHABStateDescription {
    var minimum = 0.0
    var maximum = 100.0
    var step = 1.0
    var readOnly = false

    var options: [OpenHABOptions] = []

    init(minimum: Double?, maximum: Double?, step: Double?, readOnly: Bool?, options: [OpenHABOptions]?) {
        self.minimum = minimum ?? 0.0
        self.maximum = maximum ?? 100.0
        self.step = step ?? 1.0
        self.readOnly = readOnly ?? false
        self.options = options ?? []
    }
}

extension OpenHABStateDescription {
    struct CodingData: Decodable {
        let minimum: Double?
        let maximum: Double?
        let step: Double?
        let readOnly: Bool?
        let options: [OpenHABOptions]?
    }
}

extension OpenHABStateDescription.CodingData {
    var openHABStateDescription: OpenHABStateDescription {
        OpenHABStateDescription(minimum: minimum, maximum: maximum, step: step, readOnly: readOnly, options: options)
    }
}
