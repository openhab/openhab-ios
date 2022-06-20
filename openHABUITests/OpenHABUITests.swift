// Copyright (c) 2010-2022 Contributors to the openHAB project
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

class OpenHABUITests: XCTestCase {
    override func setUp() {
        let app = XCUIApplication()
        app.launchEnvironment = ["UITest": "1"]
        setupSnapshot(app)
        continueAfterFailure = false
        app.launch()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testShots() {
        let app = XCUIApplication()

        sleep(5)
        snapshot("0_MainScreen")

        let widgetTable = app.tables["OpenHABSitemapViewControllerWidgetTableView"]

        widgetTable.staticTexts["Widget Overview"].tap()
        sleep(3)
        widgetTable/*@START_MENU_TOKEN@*/ .staticTexts["BINARY WIDGETS"]/*[[".cells.staticTexts[\"BINARY WIDGETS\"]",".staticTexts[\"BINARY WIDGETS\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .swipeDown()
        sleep(6)
        snapshot("1_WidgetOverview")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        widgetTable.staticTexts["Ground Floor"].tap()
        sleep(5)
        widgetTable.staticTexts["Kitchen"].tap()
        sleep(5)
        snapshot("2_Kitchen")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        widgetTable.staticTexts["First Floor"].tap()
        sleep(5)
        widgetTable.staticTexts["Office"].tap()
        sleep(5)
        snapshot("3_Office")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        widgetTable.staticTexts["Bathroom"].tap()
        sleep(5)
        snapshot("4_Batchroom")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        widgetTable.staticTexts["Group Demo"].tap()
        sleep(5)
        snapshot("5_GroupDemo")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        widgetTable.staticTexts["Astronomical Data"].tap()
        sleep(5)
        snapshot("6_AstronomicalData")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        let hamburgerButton = app.navigationBars.buttons["HamburgerButton"]
        hamburgerButton.tap()
        sleep(1)
        snapshot("7_Settings")
    }
}
