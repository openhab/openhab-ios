// Copyright (c) 2010-2026 Contributors to the openHAB project
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
    let runWebViewAndSitemap = true // To accelerate testing of settings set to false

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

        let hamburgerButton = app.navigationBars.buttons["line.3.horizontal"]
        hamburgerButton.tap()
        sleep(3)

        if runWebViewAndSitemap {
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

            app.staticTexts["Floorplans"].tap()
            sleep(10)
            snapshot("3_Floorplans")

            menuStaticText?.tap()
            sleep(1)
            // openHAB logo in left menu
            webViewsQuery.links.allElementsBoundByIndex[1].tap()
            sleep(2)

            app.webViews.staticTexts["square_arrow_right"].tap()

            app.staticTexts["Main Menu"].tap()
            app.cells.containing(.staticText, identifier: "Widget Overview").firstMatch.tap()
            sleep(10)
            snapshot("4_MainSitemap")

            app.staticTexts["BINARY WIDGETS"].swipeUp()
            sleep(6)
            snapshot("5_WidgetOverview")

            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(2)

            hamburgerButton.tap()
            sleep(3)
        }
        app.staticTexts["settings"].tap()
        sleep(2)
        snapshot("7_Settings_Demo")

//        let switch1 = app.switches["Demo Mode"]
        let switch1 = app.switches["1"]
        switch1.tap()
        sleep(2)
        snapshot("8_Settings_Server")
    }
}
