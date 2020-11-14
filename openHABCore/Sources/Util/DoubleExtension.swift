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

public extension Double {
    func valueText(step: Double) -> String {
        let digits = max(-Decimal(step).exponent, 0)
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = digits
        numberFormatter.maximumFractionDigits = digits
        numberFormatter.decimalSeparator = "."
        return numberFormatter.string(from: NSNumber(value: self)) ?? ""
    }
}
