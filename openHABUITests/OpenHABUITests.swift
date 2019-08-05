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
        sleep(10)
        snapshot("0_MainScreen")

        let widgetTable = app.tables["OpenHABViewControllerWidgetTableView"]

        widgetTable.staticTexts["Widget Overview"].tap()
        sleep(5)
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

        let hamburgerButton = app.navigationBars.buttons["Hamburger"]

        hamburgerButton.tap()
        sleep(1)
        snapshot("7_Settings")

   //     app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element(boundBy: 1).tap()

//        app.tables["OpenHABViewControllerWidgetTableView"].tap()
    }
}
