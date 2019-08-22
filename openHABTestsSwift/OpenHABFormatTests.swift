//
//  OpenHABFormatTests.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 09.08.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import XCTest

class OpenHABFormatTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    func testValueToText() {
        func valueText(_ widgetValue: Double, step: Double) -> String {
            let digits = max (-Decimal(step).exponent, 0)
            let numberFormatter = NumberFormatter()
            numberFormatter.minimumFractionDigits = digits
            numberFormatter.decimalSeparator  = "."
            return numberFormatter.string(from: NSNumber(value: widgetValue)) ?? ""
        }

        func valueTextWithoutFormatter(_ widgetValue: Double, step: Double) -> String {
            let digits = max (-Decimal(step).exponent, 0)
            return String(format: "%.\(digits)f", widgetValue)
        }

        XCTAssertEqual(valueText(1000.0, step: 5.23), "1000.00")
        XCTAssertEqual(valueText(1000.0, step: 1), "1000")
        XCTAssertEqual(valueTextWithoutFormatter(1000.0, step: 5.23), "1000.00")

    }
}
