//
//  openHABUITests.swift
//  openHABUITests
//
//  Created by weak on 23.07.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

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

        let widgetTable = app.tables["OpenHABViewControllerWidgetTableView"]

        widgetTable.staticTexts["Widget Overview"].tap()
        widgetTable/*@START_MENU_TOKEN@*/.staticTexts["BINARY WIDGETS"]/*[[".cells.staticTexts[\"BINARY WIDGETS\"]",".staticTexts[\"BINARY WIDGETS\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeDown()

        sleep(5)
        snapshot("1_WidgetOverview")
        app.navigationBars["Widget Overview"].buttons["Main Menu"].tap()

        sleep(2)

        widgetTable.staticTexts["Ground Floor"].tap()
        sleep(5)
//      On display of the following pane the app crashes
//        widgetTable.staticTexts["Kitchen"].tap()
//        sleep(5)
        snapshot("2_Kitchen")
//        app.navigationBars["Kitchen"].buttons["Ground Floor"].tap()
//        sleep(2)
        app.navigationBars["Ground Floor"].buttons["Main Menu"].tap()
        sleep(2)

        widgetTable.staticTexts["First Floor"].tap()
        sleep(5)
        widgetTable.staticTexts["Office"].tap()
        sleep(5)
        snapshot("3_Office")
        app.navigationBars["Office"].buttons["First Floor"].tap()
        sleep(2)

        widgetTable.staticTexts["Bathroom"].tap()
        sleep(5)
        snapshot("4_Batchroom")
        app.navigationBars["Bathroom"].buttons["First Floor"].tap()
        sleep(2)
        app.navigationBars["First Floor"].buttons["Main Menu"].tap()
        sleep(2)

        widgetTable.staticTexts["Group Demo"].tap()
        sleep(5)
        snapshot("5_GroupDemo")
        app.navigationBars["Group Demo"].buttons["Main Menu"].tap()
        sleep(2)

        widgetTable.staticTexts["Astronomical Data"].tap()
        sleep(5)
        snapshot("6_AstronomicalData")

        if #available(iOS 13.0, *) {
            app.navigationBars["Astronomical Data"].buttons["line.horizontal.3"].tap()
            sleep(1)
            snapshot("7_Settings")
        } else {
            let hamburgerButton = app.navigationBars["Astronomical Data"].buttons["Hamburger"]
            hamburgerButton.tap()
            sleep(1)
            snapshot("7_Settings")
        }
    }
}
