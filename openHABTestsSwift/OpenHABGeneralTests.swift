//
//  OpenHABFormatTests.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 09.08.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import XCTest

class OpenHABGeneralTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    func testNamedColors() {
        XCTAssertEqual("#ff0000", namedColor(toHexString: "red"))
        XCTAssertEqual(UIColor.red, color(fromHexString: "red"))
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

    func testHexString() {
        let iPhoneData: Data = "Tim iPhone".data(using: .utf8)!
        let hexWithReduce = iPhoneData.reduce("") { $0 + String(format: "%02X", $1) }
        XCTAssertEqual(hexWithReduce, "54696D206950686F6E65", "hex properly calculated with reduce")
    }

    func testEndPoints() {
        let urlc = Endpoint.icon(rootUrl: "http://192.169.2.1",
                                 version: 2,
                                 icon: "switch",
                                 value: "OFF",
                                 iconType: .svg ).url
        XCTAssertEqual(urlc, URL(string: "http://192.169.2.1/icon/switch?state=OFF&format=SVG"), "Check endpoint creation")
    }

    func testLabelVale() {
        let widget = OpenHABWidget()
        widget.label = "llldl [llsl]"
        XCTAssertEqual(widget.labelValue, "llsl")
        widget.label = "llllsl[kkks] llls"
        XCTAssertEqual(widget.labelValue, "kkks")
    }
}
