// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@testable import openHAB
import XCTest

class OpenHABGeneralTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testNamedColors() {
        XCTAssertEqual(UIColor.red, UIColor(name: "red"))
        XCTAssertEqual(UIColor(hexString: "ff00dd"), nil)
        XCTAssertEqual(UIColor(hexString: "#0000FF"), UIColor.blue)
        XCTAssertEqual(UIColor(hexString: "#0000FFd"), UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        XCTAssertEqual(UIColor(htmlName: "RED"), UIColor(red: 1, green: 0, blue: 0, alpha: 1))

        XCTAssertEqual(UIColor(name: "gold"), UIColor(red: 1, green: 0.8431372549019608, blue: 0, alpha: 1))
    }

    func testValueToText() {
        func valueText(_ widgetValue: Double, step: Double) -> String {
            let digits = max(-Decimal(step).exponent, 0)
            let numberFormatter = NumberFormatter()
            numberFormatter.minimumFractionDigits = digits
            numberFormatter.decimalSeparator = "."
            return numberFormatter.string(from: NSNumber(value: widgetValue)) ?? ""
        }

        func valueTextWithoutFormatter(_ widgetValue: Double, step: Double) -> String {
            let digits = max(-Decimal(step).exponent, 0)
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
                                 iconType: .svg).url
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
