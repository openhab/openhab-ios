//
//  StringExtension.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 20.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

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
        return formatter.number(from: self.filter("01234567890.-".contains))
    }
}
