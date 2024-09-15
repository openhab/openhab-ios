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

extension CGFloat {
    init(state string: String, divisor: Float) {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "US")
        if let number = numberFormatter.number(from: string) {
            self.init(number.floatValue / divisor)
        } else {
            self.init(0)
        }
    }
}
