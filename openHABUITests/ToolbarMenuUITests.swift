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

import XCTest

@MainActor
final class ToolbarMenuUITests: XCTestCase {
    private var app: XCUIApplication!

    private var appSettingsRow: XCUIElement {
        app.buttons["App Settings"]
    }

    private var sitemapsHeader: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] 'Sitemaps'")).firstMatch
    }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITest"] = "1"
        app.launchEnvironment["UITestOpenMenu"] = "1"
    }

    override func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }

    /// Pulling the menu down triggers a reload that keeps the menu open and populated —
    /// unlike the header's reload button, which clears the data and closes the menu.
    func testPullToRefreshKeepsMenuOpenAndPopulated() {
        app.launch()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "Menu should open via UITestOpenMenu")
        XCTAssertTrue(sitemapsHeader.waitForExistence(timeout: 20), "Demo sitemaps should load into the open menu")

        let scrollView = app.scrollViews["ToolbarMenuScrollView"]
        XCTAssertTrue(scrollView.exists, "Menu scroll view should be present")

        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = start.withOffset(CGVector(dx: 0, dy: 250))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 2), "Menu should stay open after pull-to-refresh")
        XCTAssertTrue(sitemapsHeader.waitForExistence(timeout: 20), "Sitemaps should remain listed after pull-to-refresh")
        XCTAssertTrue(sitemapsHeader.isHittable, "Sitemaps header should be interactable once the refresh settles")
    }

    /// "Add Home" opens the New Home alert. With several homes it sits behind "Edit".
    /// Which button shows for a given home count is covered by HomePickerActionTests.
    func testAddHomeOpensNewHomeAlert() {
        app.launch()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "Menu should open via UITestOpenMenu")

        let addHome = app.buttons["AddHomeButton"]
        let editHomes = app.buttons["EditHomesButton"]
        // The picker is hidden while the Homes section is collapsed; open it and restore afterwards.
        let wasCollapsed = !addHome.exists && !editHomes.exists
        let homesHeader = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Homes'")).firstMatch
        if wasCollapsed {
            XCTAssertTrue(homesHeader.waitForExistence(timeout: 5), "Homes header should be present")
            homesHeader.tap()
        }

        XCTAssertTrue(addHome.waitForExistence(timeout: 5) || editHomes.exists, "Home picker should show an action button")
        if editHomes.exists {
            editHomes.tap()
            XCTAssertTrue(addHome.waitForExistence(timeout: 2), "Edit mode should offer Add Home")
        }

        addHome.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2), "Add Home should open the New Home alert")
        XCTAssertTrue(alert.textFields.firstMatch.exists, "The alert should ask for the home name")
        alert.buttons["Cancel"].tap()

        let alertGone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: alert)
        wait(for: [alertGone], timeout: 2)
        if wasCollapsed {
            homesHeader.tap()
        }
    }
}
