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

import XCTest

@testable import openHAB
@testable import OpenHABCore

class NumberStateTest: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNumberState() throws {
        XCTAssertEqual(NumberState(value: 100.3, format: "%d").toString(locale: nil), "100")
        XCTAssertEqual(NumberState(value: 100.4, format: "%d").toString(locale: Locale(identifier: "US")), "100")
        XCTAssertEqual(NumberState(value: 100.4, format: "%d").toString(locale: Locale(identifier: "US")), "100")
        XCTAssertEqual(NumberState(value: 100.4, format: "%.1f").toString(locale: Locale(identifier: "US")), "100.4")
        XCTAssertEqual(NumberState(value: 100.4, format: "%.1f").toString(locale: Locale(identifier: "de")), "100,4")
        XCTAssertEqual(NumberState(value: 100.4, unit: "K", format: "%.1f %unit%").toString(locale: Locale(identifier: "US")), "100.4 K")
        XCTAssertEqual(NumberState(value: 100.4, unit: "", format: "%.1f %unit%").toString(locale: Locale(identifier: "US")), "100.4 ")
        XCTAssertEqual(NumberState(value: 100.4, unit: "°C", format: nil).toString(locale: Locale(identifier: "US")), "100.4 °C")
        XCTAssertEqual(NumberState(value: 100.4, unit: nil, format: nil).toString(locale: Locale(identifier: "US")), "100.4")
    }

    func testToItemType() throws {
        XCTAssertEqual("NumberItem".toItemType(), OpenHABItem.ItemType.number)
        XCTAssertEqual("Number:Temperature".toItemType(), OpenHABItem.ItemType.numberWithDimension)
        XCTAssertEqual("String".toItemType(), OpenHABItem.ItemType.stringItem)
        XCTAssertEqual("blabla".toItemType(), nil)
    }

    func testToWidgetType() throws {
        XCTAssertEqual("Colorpicker".toWidgetType(), OpenHABWidget.WidgetType.colorpicker)
        XCTAssertEqual("colorpicker".toWidgetType(), OpenHABWidget.WidgetType.unknown)
    }

    func testParseAs() throws {
        XCTAssertEqual("ON".parseAsBool(), true)
        XCTAssertEqual("4,3,1".parseAsBrightness(), 1)
        XCTAssertEqual("4,31".parseAsBrightness(), nil)
        XCTAssertEqual("4,3,0".parseAsBool(), false)
        XCTAssertEqual("4,3,1".parseAsBool(), true)
        XCTAssertEqual("1".parseAsBool(), true)
        XCTAssertEqual("0".parseAsBool(), false)
        XCTAssertEqual("ON".parseAsNumber(), NumberState(value: 100.0))
        XCTAssertEqual("OFF".parseAsNumber(), NumberState(value: 0.0))
        XCTAssertEqual("24.4 °F".parseAsNumber(), NumberState(value: 24.4, unit: "°F", format: nil))
        XCTAssertEqual("24.4 °F".parseAsNumber(format: "%.f"), NumberState(value: 24.4, unit: "°F", format: "%.f"))
        let col1 = "Uninitialized".parseAsUIColor()
        let col2 = UIColor(hue: 0, saturation: 0, brightness: 0, alpha: 1.0)
        XCTAssert(col1!.equals(col2))
        XCTAssertEqual("360,100,100".parseAsUIColor(), UIColor(hue: CGFloat(state: "360", divisor: 360), saturation: CGFloat(state: "100", divisor: 100), brightness: CGFloat(state: "100", divisor: 100), alpha: 1.0))
    }
}

extension UIColor {
    func equals(_ rhs: UIColor) -> Bool {
        var lhsR: CGFloat = 0
        var lhsG: CGFloat = 0
        var lhsB: CGFloat = 0
        var lhsA: CGFloat = 0
        getRed(&lhsR, green: &lhsG, blue: &lhsB, alpha: &lhsA)

        var rhsR: CGFloat = 0
        var rhsG: CGFloat = 0
        var rhsB: CGFloat = 0
        var rhsA: CGFloat = 0
        rhs.getRed(&rhsR, green: &rhsG, blue: &rhsB, alpha: &rhsA)

        return lhsR == rhsR &&
            lhsG == rhsG &&
            lhsB == rhsB &&
            lhsA == rhsA
    }
}
