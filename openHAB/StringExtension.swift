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

extension String {
    var doubleValue: Double {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."
        if let asNumber = formatter.number(from: self) {
            return asNumber.doubleValue
        } else {
            return Double.nan
        }
    }

    var intValue: Int {
        if let asNumber = NumberFormatter().number(from: self) {
            return asNumber.intValue
        } else {
            return Int.max
        }
    }

    /**
     Transforms the string received in json response into NSNumber
     Independent of locale's decicmal separator

     */
    var numberValue: NSNumber? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = "."
        return formatter.number(from: filter("01234567890.-".contains))
    }
}
