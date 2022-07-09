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

import os.log
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
        let hamburgerButton = app.navigationBars/*@START_MENU_TOKEN@*/ .buttons["HamburgerButton"]/*[[".buttons[\"drag\"]",".buttons[\"HamburgerButton\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        hamburgerButton.tap()
        sleep(3)

        let tablesQuery = app.tables
        tablesQuery/*@START_MENU_TOKEN@*/ .staticTexts["Home"]/*[[".cells.staticTexts[\"Home\"]",".staticTexts[\"Home\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()
        sleep(10)
        snapshot("0_MainUI")

        // Locations Tab
        let webViewsQuery = app.webViews.webViews.webViews
        webViewsQuery.links["placemark_fill Locations"].tap()
        sleep(2)
        snapshot("1_Locations")

        webViewsQuery.staticTexts["Living Room"].tap()
        sleep(2)
        snapshot("2_LivingRoom")
        // Close button on Living Room view
        webViewsQuery.otherElements["openHAB"].children(matching: .link).matching(identifier: "multiply_circle_fill").element(boundBy: 0).staticTexts["multiply_circle_fill"].tap()
        sleep(2)

        // Left side menu in webUI
        let menuStaticText = webViewsQuery/*@START_MENU_TOKEN@*/ .staticTexts["menu"]/*[[".otherElements[\"openHAB\"]",".links.matching(identifier: \"menu\").staticTexts[\"menu\"]",".staticTexts[\"menu\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        menuStaticText.tap()
        sleep(1)
        webViewsQuery.staticTexts["Floorplans"].tap()
        sleep(2)
        snapshot("3_Floorplans")

        menuStaticText.tap()
        sleep(1)
        // openHAB logo in left menu
        webViewsQuery.otherElements["openHAB"].children(matching: .other).element(boundBy: 0).children(matching: .link).element.children(matching: .link).element.children(matching: .image).element.tap()
        sleep(2)

        // right menu in webUI
        webViewsQuery/*@START_MENU_TOKEN@*/ .staticTexts["square_arrow_right"]/*[[".otherElements[\"openHAB\"]",".links.matching(identifier: \"square_arrow_right\").staticTexts[\"square_arrow_right\"]",".staticTexts[\"square_arrow_right\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .tap()
        tablesQuery.staticTexts["Main Menu"].tap()
        sleep(5)
        snapshot("4_MainSitemap")

        let widgetTable = app.tables["OpenHABSitemapViewControllerWidgetTableView"]

        widgetTable.staticTexts["Widget Overview"].tap()
        sleep(3)
        widgetTable/*@START_MENU_TOKEN@*/ .staticTexts["BINARY WIDGETS"]/*[[".cells.staticTexts[\"BINARY WIDGETS\"]",".staticTexts[\"BINARY WIDGETS\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .swipeDown()
        sleep(6)
        snapshot("5_WidgetOverview")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        widgetTable.staticTexts["Ground Floor"].tap()
        sleep(5)
        widgetTable.staticTexts["Kitchen"].tap()
        sleep(5)
        snapshot("6_Kitchen")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        hamburgerButton.tap()
        sleep(2)
        tablesQuery.staticTexts["Settings"].tap()
        sleep(2)
        snapshot("7_Settings")
    }
}
