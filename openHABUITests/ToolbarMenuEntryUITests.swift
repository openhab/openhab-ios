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

/// Choosing an entry in the menu does something the user can see. These tests do not say what an
/// entry opens, nor in what kind of view: a page, a sheet or something else all count. They only
/// hold that the menu is left, and that the screen is a different one than it was before the menu
/// was opened.
///
/// The screen is compared with the menu closed on both sides. While the menu is open, the screen
/// behind it is not visible to the tests, so a screen seen then and one seen after the menu has
/// closed always differ, whatever the entry did.
@MainActor
final class ToolbarMenuEntryUITests: XCTestCase {
    private var app: XCUIApplication!

    private let server = """
    {"version":"5.0.0","endpoints":["items","things","rules","ui","addons"],\
    "pages":[{"uid":"uitest_page","label":"UITest Page"}],\
    "sitemaps":[{"name":"home","label":"UITest Sitemap"}]}
    """

    private var menuIsOpen: XCUIElement {
        app.buttons["App Settings"]
    }

    private var homeRow: XCUIElement {
        app.buttons["Home"]
    }

    private var sitemapRow: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "home").firstMatch
    }

    private var pageRow: XCUIElement {
        app.buttons["UITest Page"]
    }

    private var aboutRow: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "MainUIEntry-about").firstMatch
    }

    private var notificationsRow: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] 'Notifications'")).firstMatch
    }

    /// What is on screen, in terms that hold for any kind of view: the navigation bars by title
    /// and how many web views there are. Tables and collections are left out on purpose: they come
    /// and go with the content of a page, which says nothing about what the menu did.
    private var screen: [String] {
        app.navigationBars.allElementsBoundByIndex.map { "bar:\($0.identifier)" } + [
            "webViews:\(app.webViews.count)"
        ]
    }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.useEnglishLocale()
        app.launchEnvironment["UITest"] = "1"
        app.launchEnvironment["UITestServer"] = server
        app.launchEnvironment["UITestNotifications"] = "1"
    }

    override func tearDown() async throws {
        app = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Lets `seconds` pass without blocking the run loop the app's UI is observed through.
    private func pause(_ seconds: TimeInterval) {
        let never = XCTestExpectation(description: "pause")
        never.isInverted = true
        _ = XCTWaiter().wait(for: [never], timeout: seconds)
    }

    /// The screen once it has stopped changing: pages load, and their title and web views arrive
    /// some time after the app has started or a page was chosen.
    private func settledScreen() -> [String] {
        var current = screen
        var unchangedSamples = 0
        for _ in 0 ..< 40 where unchangedSamples < 4 {
            pause(0.5)
            let sample = screen
            unchangedSamples = sample == current ? unchangedSamples + 1 : 0
            current = sample
        }
        return current
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(app.buttons["HamburgerButton"].waitForExistence(timeout: 10), "The menu button is there")
    }

    /// Opens the menu from its button, taps `entry` and holds that the screen is a different one
    /// than before the menu was opened.
    /// - Parameter leavesMenu: Whether the menu is expected to close. Settings sheets open over it.
    private func choose(_ entry: XCUIElement, named name: String, leavesMenu: Bool = true) {
        let before = settledScreen()

        app.buttons["HamburgerButton"].tap()
        XCTAssertTrue(menuIsOpen.waitForExistence(timeout: 5), "The menu opens from its button")
        XCTAssertTrue(entry.waitForExistence(timeout: 20), "'\(name)' is in the menu")
        entry.tap()

        if leavesMenu {
            let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: menuIsOpen)
            wait(for: [closed], timeout: 5)
        }

        let changed = expectation(for: NSPredicate { _, _ in self.screen != before }, evaluatedWith: nil)
        let result = XCTWaiter().wait(for: [changed], timeout: 10)
        XCTAssertEqual(
            result, .completed,
            "Choosing '\(name)' showed nothing new: the screen is still \(before)"
        )
    }

    // MARK: - Entries

    /// The notifications open over the menu, which stays, like the settings.
    func testNotificationsEntryShowsSomething() {
        launch()
        choose(notificationsRow, named: "Notifications", leavesMenu: false)
    }

    private func openNotifications() {
        launch()
        app.buttons["HamburgerButton"].tap()
        XCTAssertTrue(notificationsRow.waitForExistence(timeout: 20), "Notifications is in the menu")
        notificationsRow.tap()
        XCTAssertTrue(app.staticTexts["UITest Front Door Alert"].waitForExistence(timeout: 10), "The notifications show")
    }

    /// Closing the notifications leaves the menu where it was.
    func testClosingTheNotificationsKeepsTheMenu() {
        openNotifications()

        app.buttons["Back"].tap()

        let closed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.staticTexts["UITest Front Door Alert"]
        )
        wait(for: [closed], timeout: 5)
        XCTAssertTrue(menuIsOpen.waitForExistence(timeout: 5), "The menu stays open behind the notifications")
    }

    /// Choosing a notification action takes the user elsewhere, so the menu goes too.
    func testChoosingANotificationActionClosesTheMenu() {
        openNotifications()

        app.staticTexts["UITest Front Door Alert"].press(forDuration: 1)
        app.buttons["Open Camera"].tap()

        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: menuIsOpen)
        wait(for: [closed], timeout: 5)
        XCTAssertFalse(app.staticTexts["UITest Front Door Alert"].exists, "The notifications are gone")
    }

    func testSitemapEntryShowsSomething() {
        launch()
        choose(sitemapRow, named: "Sitemap")
    }

    /// Home is where the app starts, so it is chosen after leaving it.
    func testHomeEntryShowsSomething() {
        launch()
        choose(sitemapRow, named: "Sitemap")
        choose(homeRow, named: "Home")
    }

    func testMainUIPageEntryShowsSomething() {
        launch()
        choose(sitemapRow, named: "Sitemap")
        choose(pageRow, named: "Main UI page")
    }

    func testMainUIEntryShowsSomething() {
        launch()
        choose(sitemapRow, named: "Sitemap")
        choose(aboutRow, named: "About")
    }

    /// The settings open over the menu, which stays.
    func testAppSettingsEntryShowsSomething() {
        launch()
        choose(menuIsOpen, named: "App Settings", leavesMenu: false)
    }
}
