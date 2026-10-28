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
        app.useEnglishLocale()
        app.launchEnvironment["UITest"] = "1"
        app.launchEnvironment["UITestOpenMenu"] = "1"
    }

    override func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }

    /// Opening the menu loads its entries.
    func testOpenMenuIsPopulated() {
        app.launch()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "Menu should open via UITestOpenMenu")
        XCTAssertTrue(sitemapsHeader.waitForExistence(timeout: 20), "Demo sitemaps should load into the open menu")
        XCTAssertTrue(sitemapsHeader.isHittable, "Sitemaps header should be interactable once the menu has loaded")
    }

    /// The menu opens from its button while the home is still loading, so the user can switch to
    /// another home or page when loading is slow or stuck.
    func testMenuOpensWhileTheHomeIsLoading() {
        app.launchEnvironment["UITestOpenMenu"] = nil
        app.launch()

        let menuButton = app.buttons["HamburgerButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "The menu button should show while loading")
        XCTAssertTrue(menuButton.isHittable, "The menu button should be tappable while loading")
        menuButton.tap()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "The menu should open while the home is loading")
    }

    /// The menu opens again after the user picked a home in it, which swaps the screen behind the
    /// menu button while the menu closes.
    func testMenuReopensAfterPickingAHome() {
        app.launch()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "Menu should open via UITestOpenMenu")
        let homesHeader = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Homes'")).firstMatch
        XCTAssertTrue(homesHeader.waitForExistence(timeout: 20), "Homes header should be present")
        homesHeader.tap()

        // The home rows are static texts of their own; the header's label is inside its button.
        let homeRow = app.staticTexts.matching(NSPredicate(format: "label == 'Home#1'")).allElementsBoundByIndex
            .first { $0.isHittable && !homesHeader.frame.contains($0.frame) }
        XCTAssertNotNil(homeRow, "The home list should show the home")
        homeRow?.tap()

        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: appSettingsRow)
        wait(for: [closed], timeout: 5)

        let menuButton = app.buttons["HamburgerButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "The menu button should be back")
        menuButton.tap()
        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "The menu should open again after the home switch")
    }

    /// A tap outside the popover closes it.
    func testTapOutsideClosesTheMenu() {
        app.launch()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "Menu should open via UITestOpenMenu")
        // The tap is only taken once the popover has finished appearing, which a loaded menu has.
        XCTAssertTrue(sitemapsHeader.waitForExistence(timeout: 20), "Demo sitemaps should load into the open menu")

        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.9)).tap()

        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: appSettingsRow)
        wait(for: [closed], timeout: 3)
    }

    /// The menu grows with its content up to the room the display has, not to a fixed height, and
    /// leaves some space below it to tap on.
    func testMenuGrowsToTheRoomItHas() {
        app.launch()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "Menu should open via UITestOpenMenu")
        XCTAssertTrue(sitemapsHeader.waitForExistence(timeout: 20), "Demo sitemaps should load into the open menu")

        let menu = app.scrollViews["ToolbarMenuScrollView"]
        let window = app.windows.firstMatch.frame
        // The content of the demo server's menu is well over 480 points tall.
        let grown = NSPredicate { _, _ in menu.frame.height > 520 }
        let expectation = expectation(for: grown, evaluatedWith: nil)
        wait(for: [expectation], timeout: 5)
        XCTAssertLessThanOrEqual(menu.frame.maxY, window.maxY - 44, "Space is left below the menu to tap on")
    }

    /// A pull down on the menu reloads it and does not close it.
    func testPullDownReloadsAndKeepsTheMenuOpen() {
        app.launch()

        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5), "Menu should open via UITestOpenMenu")
        XCTAssertTrue(sitemapsHeader.waitForExistence(timeout: 20), "Demo sitemaps should load into the open menu")

        let scrollView = app.scrollViews["ToolbarMenuScrollView"]
        // The debug build reports how often the menu reloaded as the scroll view's value.
        let reloadsBefore = Int(scrollView.value as? String ?? "") ?? 0
        let top = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        top.press(forDuration: 0.1, thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))

        let reloaded = expectation(
            for: NSPredicate { _, _ in (Int(scrollView.value as? String ?? "") ?? 0) > reloadsBefore },
            evaluatedWith: nil
        )
        wait(for: [reloaded], timeout: 5)
        XCTAssertTrue(appSettingsRow.exists, "A pull down should not close the menu")
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
