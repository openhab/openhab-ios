// Copyright (c) 2010-2025 Contributors to the openHAB project
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
    override func setUp() async throws {
        try await super.setUp()

        let app = await XCUIApplication()
        await MainActor.run {
            app.launchEnvironment = ["UITest": "1"]
        }
        continueAfterFailure = false
        await setupSnapshot(app)
        await app.launch()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testShots() {
        let app = XCUIApplication()
        app.activate()

        let hamburgerButton = app.navigationBars.buttons["HamburgerButton"]
        hamburgerButton.tap()
        sleep(3)

        app.staticTexts["Home"].tap()
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

        var menuStaticText: XCUIElement?
        // if we have a left side menu, then use it (large screens like 12.9 inch iPad will not)
        if !webViewsQuery.staticTexts["Floorplans"].exists {
            // Left side menu in webUI
            menuStaticText = webViewsQuery.staticTexts["menu"]
            sleep(2)
            menuStaticText?.tap()
            sleep(1)
        }

        app/*@START_MENU_TOKEN@*/ .staticTexts["Floorplans"]/*[[".links[\"Floorplans\"].staticTexts.firstMatch",".links.staticTexts[\"Floorplans\"]",".staticTexts[\"Floorplans\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()
        sleep(10)
        snapshot("3_Floorplans")

        menuStaticText?.tap()
        sleep(1)
        // openHAB logo in left menu
        webViewsQuery.links.allElementsBoundByIndex[1].tap()
        sleep(2)

        app.webViews/*@START_MENU_TOKEN@*/ .staticTexts["square_arrow_right"]/*[[".links[\"square_arrow_right\"].staticTexts.firstMatch",".links.staticTexts[\"square_arrow_right\"]",".staticTexts[\"square_arrow_right\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()

        app/*@START_MENU_TOKEN@*/ .staticTexts["Main Menu"]/*[[".otherElements.staticTexts[\"Main Menu\"]",".staticTexts[\"Main Menu\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()
        app.cells/*@START_MENU_TOKEN@*/ .containing(.staticText, identifier: "Widget Overview").firstMatch/*[[".element(boundBy: 11)",".containing(.staticText, identifier: \"Widget Overview\").firstMatch"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .tap()
        sleep(10)
        snapshot("4_MainSitemap")

        app.staticTexts["BINARY WIDGETS"].swipeUp()
        sleep(6)
        snapshot("5_WidgetOverview")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)

        hamburgerButton.tap()
        sleep(3)
        app.staticTexts["settings"].tap()
        sleep(2)
        snapshot("7_Settings_Demo")

        app.staticTexts["Demo Mode"].tap()
        sleep(2)
        snapshot("8_Settings_Server")
    }
}
